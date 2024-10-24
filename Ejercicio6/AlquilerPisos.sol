// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AlquilerPisos {
    
    // Usuarios del contrato
    address payable public arrendador;
    address payable public arrendatario;

    // Parámetros del contrato de alquiler
    uint public precioAlquiler;
    uint public fianzaAlquiler;
    uint public duracionContrato;
    uint public fechaInicioContrato;
    uint public fechaVencimientoPago;
    bool public fianzaDevuelta;
    bool public contratoActivo;
    bool public pagoPrimerMes;
    uint public penalizacion;
    enum motivosFinalizacion {INCUMPLIMIENTO, MUTUOACUERDO, NORENOVACION, DESALOJO, DAMAGE, CAMBIOARRENDADOR, RENUNCIA}

    //Propuesta nuevo contrato
    uint public nuevaDuracionPropuesta;
    uint public nuevoPrecioPropuesta;
    bool public propuestaPendiente = false;
    uint public plazoPropuesta;
    
    // Eventos
    event pagoRealizado(uint _precio, uint _fecha);
    event devolucionFianza(uint _fianza, uint _fechaDevolucion);
    event propuestaRenovacion(uint _duracionNuevoContrato, uint _nuevoPrecioAlquiler);
    event acuerdoAlcanzado(uint _duracionContrato, uint _precioAlquiler);
    event contratoFinalizado(address arrendatario, motivosFinalizacion motivo, uint fechaFinalizacion);
    event penalizacionEstablecida(uint _penalziacion);
    event penalizacionPagada(uint _monto, uint _fecha);

    // Modificadores
    modifier soloArrendador(){
        require(msg.sender == arrendador, "Solo puede realizar la accion el arrendador.");
        _;
    }

    modifier soloArrendatario(){
        require(msg.sender == arrendatario, "Solo puede realizar la accion el arrendatario.");
        _;
    }

    // Constructor
    constructor(address payable _inquilino, uint _precioAlquiler, uint _fianza, uint _duracionContrato){
        arrendador = payable(msg.sender);
        arrendatario = _inquilino;
        precioAlquiler = _precioAlquiler * 1 ether;
        fianzaAlquiler = _fianza * 1 ether;
        duracionContrato = _duracionContrato;
        fechaInicioContrato = block.timestamp;
        fechaVencimientoPago = block.timestamp + 30 days; // 30 days -> minutos
        pagoPrimerMes = true;
    }

    // Pago de alquiler  
    function pagarAlquiler() public payable soloArrendatario{
        require(block.timestamp <= fechaVencimientoPago, "Se ha excedido la fecha de pago.");
        require(contratoActivo == true, "El contrato no esta activo");
        
        uint256 cantidadPago;
        if(pagoPrimerMes){
            cantidadPago = precioAlquiler + fianzaAlquiler;   
            pagoPrimerMes = false;       
        }else{
            cantidadPago = precioAlquiler;
        }
        require(msg.value == cantidadPago, "La cantidad de dinero no es exacta");
        
        
        arrendador.transfer(msg.value);  
        fechaVencimientoPago += 30 days;
        
        emit pagoRealizado(msg.value, block.timestamp);
    }

    // Devolución de fianza
    function devolverFianza(uint _fianzaIncumplimiento) public payable soloArrendador {
        require (block.timestamp >= fechaInicioContrato + duracionContrato, "El contrato no ha finalizado.");
        require (_fianzaIncumplimiento <= fianzaAlquiler, "No se puede devolver mas dinero del estipulado por la fianza.");
        require (fianzaDevuelta == false, "La fianza ya ha sido devuelta.");
        
        uint fianzaADevolver = fianzaAlquiler - _fianzaIncumplimiento;
        
       //arrendatario.transfer(fianzaADevolver);
        (bool success, ) = arrendatario.call{value: fianzaADevolver}("");
        require(success, "Fallo al enviar el Ether");
        fianzaDevuelta = true;
        emit devolucionFianza(fianzaADevolver, block.timestamp);
    }

    function proponerContrato(uint _nuevaDuracionContrato,uint _nuevoPrecioAlquiler) public soloArrendador{
         if(contratoActivo==true){
            uint fechaFinContrato = fechaInicioContrato+duracionContrato;
            //Comprobaciones para proponer un nuevo contrato
            require(((fechaFinContrato - block.timestamp) >=  30 days), "Quedan menos de 30 dias hasta el fin del contrato");
        }
        require(propuestaPendiente == false, "Ya hay una propuesta de contrato pendiente");
       
        //nueva proposicion
        nuevaDuracionPropuesta = _nuevaDuracionContrato*60 seconds;
        nuevoPrecioPropuesta = _nuevoPrecioAlquiler;
        propuestaPendiente = true;
        plazoPropuesta = block.timestamp;

        //aceptar contrato
        emit propuestaRenovacion(_nuevaDuracionContrato, _nuevoPrecioAlquiler);     
        
    }
    function aceptarContrato() public soloArrendatario{
        require(propuestaPendiente == true, "No hay ninguna propuesta de contrato");
        require(plazoPropuesta + 30 days >= block.timestamp, "La propuesta ha finalizado");

        duracionContrato = nuevaDuracionPropuesta;
        precioAlquiler = nuevoPrecioPropuesta;
        propuestaPendiente = false;
        contratoActivo = true; //Se acepta el contrato

        emit acuerdoAlcanzado(duracionContrato, precioAlquiler);
    }

    function finalizarContrato(motivosFinalizacion motivo, uint fianzaDeducida) public soloArrendador() {
        require(contratoActivo == true, "El contrato no esta activo");
        contratoActivo = false;

        if (motivo == motivosFinalizacion.CAMBIOARRENDADOR){
            // Si se finaliza el contrato por cambio de arrendador,
            arrendador = payable(msg.sender);
        } else if (motivo == motivosFinalizacion.DAMAGE || motivo == motivosFinalizacion.INCUMPLIMIENTO || motivo == motivosFinalizacion.RENUNCIA) {
            // Si se finaliza el contrato por daños o incumplimiento, se reduce o retiene la fianza completa.
            devolverFianza(fianzaDeducida);
        } else if (motivo == motivosFinalizacion.DESALOJO) {
            // ¿que hacemos aqui?
            devolverFianza(fianzaAlquiler); // No se devuelve nada de la fianza & penalizacion ?
            arrendador.transfer(fianzaAlquiler/10);
          
        } else if (motivo == motivosFinalizacion.MUTUOACUERDO || motivo == motivosFinalizacion.NORENOVACION) {
            // Si se finaliza el contrato por mutuo acuerdo o por no renovación, se devuelve la fianza al completo.
            devolverFianza(0);
        } 

        emit contratoFinalizado(arrendatario, motivo, block.timestamp);
    }

    // Penalización en caso de impago
    function penalizarPorImpago() external soloArrendador {
        require(block.timestamp > fechaVencimientoPago, "El plazo de pago no ha finalizado todavia.");
        penalizacion = (block.timestamp - fechaVencimientoPago) / 1 days * 0.05 ether;
        
        emit penalizacionEstablecida(penalizacion);
    }

    function pagarPenalizacion() public payable soloArrendatario {
        require(block.timestamp > fechaVencimientoPago, "El plazo de pago no ha finalizado todavia.");
        require(msg.value == penalizacion, "Introduce el monto correcto de penalizacion.");

        arrendador.transfer(msg.value);
        
        emit penalizacionPagada(msg.value,block.timestamp);
    }


}
