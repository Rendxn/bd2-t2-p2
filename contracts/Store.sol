pragma solidity ^0.8.4;

// SPDX-License-Identifier: MIT

import "./_Owned.sol";
import "./_Destructible.sol";

/**
 * Tienda en la que interactuan clientes y dueño.
 *
 * 1. Un único DUEÑO (owner)
 *
 *  - *Crear productos con la siguiente estructura:
 *
 *      nombre (único)
 *      descripción
 *      precio unitario
 *      inventario
 *
 *  - *Consultar total de todas las compras.
 *  - *Consultar total de todas las compras por país.
 *  - *Consultar total de todas las deudas de clientes.
 *  - *Puede destruir el contrato al 3er intento.
 *
 * 2. CLIENTE
 *
 *  - *El CLIENTE debe registrarse antes de comprar o comprar fiado. El registro tiene la siguiente estructura:
 *
 *      código (único)
 *      nombre
 *      país de origen
 *
 *  - *Si un cliente ha gastado más de 50 ETH en la tienda (sin incluir deudas)
 *    se restan 3 ETH siempre y cuando el resultado sea mayor o igual a 0.
 *  - *Al comprar fiado, contrae una deuda por el valor de la compra.
 *  - *Si tiene una deuda, no puede comprar más hasta que la pague.
 *
 *  - *Consultar el valor de su deuda y pagar exactamente ese valor.
 *  - *Consultar total de todas sus compras (sin incluir deudas).
 *  - *Consultar el precio final de un producto, buscando por nombre.
 *  - *Consultar los datos de un producto, buscando por nombre.
 *
 *  - *Debe enviar el valor exacto cuando compra.
 *  - *Solo puede comprar un producto a la vez.
 *  - *La compra fiada no recibe ETH, pero registra al cliente y su deuda.
 */

contract Store is Owned, Destructible {
    
    struct Product {
        string name;
        string description;
        uint256 price;
        uint256 stock;
    }

    struct Customer {
        uint256 id;
        string name;
        string country;
        uint256 spent;
        uint256 debt;
    }

    mapping(string => Product) private products;

    mapping(address => Customer) private customers;
    mapping(uint256 => bool) private registered;

    mapping(string => uint256) private purchasesCountry;

    uint256 private totalPurchases;
    uint256 private totalDebts;
    
    event Purchase(address buyer, string method, string product, uint256 value);
    event CreditPayment(address buyer, uint256 value);

    /**
     * Registrar un producto
     */

    function addProduct(
        string memory _name,
        string memory _description,
        uint256 _price,
        uint256 _stock
    ) 
    public 
    onlyOwner
    {
        products[_name] = Product(_name, _description, _price, _stock);
    }

    /**
     * Registrar un cliente
     */

    function addCustomer(
        uint256 _id,
        string memory _name,
        string memory _country
    ) 
    public
    {
        // Verifica que la id no esté registrada.
        require(registered[_id] == false, "Este usuario ya existe");
        // Registra el nuevo cliente.
        Customer memory customer = customers[msg.sender];
        customer.id = _id;
        customer.name = _name;
        customer.country = _country;
        customers[msg.sender] = customer;
        registered[_id] = true;
    }

    /**
     * Compra de un producto.
     */

    function purchase(string memory productName)
        public
        payable
        onlyRegisteredCustomer
        onlyCleanCustomer
        inStock(productName)
        costs(getProductPrice(productName))
    {
        Customer memory customer = customers[msg.sender];

        // Guarda cuánto gastó el cliente.
        uint256 price = getProductPrice(productName);
        customer.spent += price;
        customers[msg.sender] = customer;
        totalPurchases += price;
        purchasesCountry[customer.country] += price;
        // Transfiere el dinero al dueño.
        owner.transfer(msg.value);
        // Reduce el stock
        Product memory product = products[productName];
        product.stock--;
        products[productName] = product;
        emit Purchase(msg.sender, "CASH", product.name, product.price);
    }

    /**
     * Compra de un producto con crédito.
     */

    function creditPurchase(string memory productName)
        public
        onlyRegisteredCustomer
        onlyCleanCustomer
        inStock(productName)
    {
        Customer memory customer = customers[msg.sender];

        // Registra cuánto debe el cliente.
        // TODO: REFACTOR INTO FUNCTIONS
        uint256 price = getProductPrice(productName);
        customer.debt += price;
        customers[msg.sender] = customer;
        totalDebts += price;
        // Reduce el stock
        Product memory product = products[productName];
        product.stock--;
        products[productName] = product;
        emit Purchase(msg.sender, "CREDIT", product.name, product.price);
    }
    
    /**
     * Pago de crédito.
     */

    function payCredit()
        public
        payable
        onlyRegisteredCustomer
        costs(customers[msg.sender].debt)
    {
        Customer memory customer = customers[msg.sender];
        // Transfiere el dinero al dueño.
        owner.transfer(msg.value);
        // Actualiza las deudas.
        customer.spent += customer.debt;
        totalDebts -= customer.debt;
        totalPurchases += customer.debt;
        purchasesCountry[customer.country] += customer.debt;
        emit CreditPayment(msg.sender, customer.debt);
        
        customer.debt = 0;
        customers[msg.sender] = customer;
    }
    

    /**
     * Getter de products.
     */

    function getProduct(string memory productName) 
    public 
    view 
    onlyRegisteredCustomer
    returns (string memory name, string memory description, uint256 price, uint256 stock)
    {
        Product memory product = products[productName];
        name = product.name;
        description = product.description;
        price = product.price;
        stock = product.stock;
    }
    
    
    /**
     * Getter de gastos de cliente.
     */

    function getSpent() public view onlyRegisteredCustomer returns (uint256) {
        return customers[msg.sender].spent;
    }
    
    
    /**
     * Getter de deudas de cliente.
     */

    function getDebt() public view onlyRegisteredCustomer returns (uint256) {
        return customers[msg.sender].debt;
    }
    
    
    /**
     * Getter de totalPurchases.
     */

    function getTotalPurchases() public view onlyOwner returns (uint256) {
        return totalPurchases;
    }

    /**
     * Getter de purchasesCountry.
     */

    function getPurchasesCountry(string memory _country)
        public
        view
        onlyOwner
        returns (uint256)
    {
        return purchasesCountry[_country];
    }
    

    /**
     * Getter de totalDebts.
     */

    function getTotalDebts() public view onlyOwner returns (uint256) {
        return totalDebts;
    }
    

    /**
     * Getter de totalPurchases.
     */

    function getProductPrice(string memory _name)
        public
        view
        returns (uint256)
    {
        Product memory product = products[_name];

        if (customers[msg.sender].spent > 50 && product.price < 3)
            return (product.price - 3);

        return product.price;
    }
    

    /**
     * Solo clientes que no tengan deudas.
     */
    modifier onlyCleanCustomer() {
        require(
            customers[msg.sender].debt == 0,
            "Debes pagar tus deudas antes de hacer otras compras"
        );
        _;
    }


    /**
     * Solo clientes registrados.
     */
    modifier onlyRegisteredCustomer() {
        require(
            registered[customers[msg.sender].id] == true,
            "Debes registrarte antes de comprar"
        );
        _;
    }

    /**
     * Solo si el producto está en stock.
     */
    modifier inStock(string memory _name) {
        require(products[_name].stock > 0, "El producto no tiene existencias");
        _;
    }


    /*
     * Que el valor sí sea mayor o igual al precio del producto.
     */
    modifier costs(uint256 price) {
        require(
            msg.value == price * (1 ether),
            "Debe ingresar el valor exacto"
        );
        _;
    }
}
