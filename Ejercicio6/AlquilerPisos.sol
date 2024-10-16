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
    bool public renovacionAceptadaPorArrendatario;
    bool public renovacionAceptadaPorArrendador;
    bool public pagoPrimerMes = false;
    
    // Eventos
    event pagoRealizado(uint _precio, uint _fecha);
    event devolucionFianza(uint _fianza, uint _fechaDevolucion);
    event propuestaRenovacion(uint _duracionNuevoContrato, uint _nuevoPrecioAlquiler);
    event acuerdoAlcanzado(uint _duracionContrato, uint _precioAlquiler);
   // event contratoRenovado

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
        precioAlquiler = _precioAlquiler;
        fianzaAlquiler = _fianza;
        duracionContrato = _duracionContrato;
        fechaInicioContrato = block.timestamp;
        fechaVencimientoPago = block.timestamp + 30 days;
        contratoActivo = true;
    }

    // Pago de alquiler
    function pagarAlquiler() public payable soloArrendatario{
        require(block.timestamp <= fechaVencimientoPago, "Se ha excedido la fecha de pago.");
        
        uint256 cantidadPago;
        if(fechaInicioContrato <= block.timestamp &&  block.timestamp <= fechaVencimientoPago){
            cantidadPago = precioAlquiler + fianzaAlquiler;          
        }else{
            cantidadPago = precioAlquiler;
        }
        require(msg.value == cantidadPago, "La cantidad de dinero no es exacta");
          
        arrendador.transfer(msg.value);  
        
        emit pagoRealizado(msg.value, block.timestamp);
    }

    // Devolución de fianza
    function devolverFianza(uint _fianzaIncumplimiento) public payable soloArrendador {
        require (block.timestamp >= fechaInicioContrato + duracionContrato, "El contrato no ha finalizado.");
        require (_fianzaIncumplimiento <= fianzaAlquiler, "No se puede devolver mas dinero del estipulado por la fianza.");

        fianzaDevuelta = true;
        
        arrendatario.transfer(msg.value);

        emit devolucionFianza(_fianzaIncumplimiento, block.timestamp);
    }
    //renovar contrato
    function renovarContrato() public soloArrendador{

    }

    function proponerContrato(uint _nuevaDuracionContrato,uint _nuevaFianzaAlquiler) public soloArrendador{
        uint fechaFinContrato = fechaInicioContrato+duracionContrato;
        //Comprobaciones
        require((contratoActivo == true)&&((fechaFinContrato - block.timestamp) >= 30 * 86400), "Quedan menos de 30 dias hasta el fin del contrato");
        require((contratoActivo == false)&&(fechaFinContrato > block.timestamp), "El contrato ya finalizo");
       
       //aceptar contrato

       //
        
        
    }
    function aceptarContrato() public soloArrendatario{



        emit acuerdoAlcanzado(nuevaDuracion, nuevoPrecio);
    }


    //finalizar contrato / en caso de incumplimiento
    //verificar que el contrato siga activo
    //reclamar deposito por daños???
}