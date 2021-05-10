pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./Wallet.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Dex is Wallet {
    using SafeMath for uint256;

    enum Side {
        BUY,
        SELL
    }

    struct Order {
        uint id;
        address trader;
        Side side;
        bytes32 ticker;
        uint amount;
        uint price;
        uint filled;
    }

    uint public nextOrderId = 0;

    mapping(bytes32 => mapping(uint => Order[])) orderBook;

    function getOrderBook(bytes32 ticker, Side side) view public returns(Order[] memory){
        return orderBook[ticker][uint(side)];
    }

    function createLimitOrder(Side side, bytes32 ticker, uint amount, uint price) tokenExist(ticker) public {
        if(side == Side.BUY){
            require(balances[msg.sender]["ETH"] >= amount.mul(price), "Not enough balance");
        }
        else if(side == Side.SELL){
            require(balances[msg.sender][ticker] >= amount, "Not enough balance");
        }
        //require(trader == msg.sender);
        //require();

        Order[] storage orders = orderBook[ticker][uint(side)];

        orders.push(
            Order(nextOrderId,msg.sender,side,ticker,amount,price,0)
            );

        uint length = orders.length;

        if (side == Side.BUY && length > 1){
            for(uint i = 1; i <= length-1; i++){
                if(orders[length-i].price >= orders[length-i-1].price){
                    Order memory tempOrder =  orders[length-i];
                    orders[length-i] = orders[length-i-1];
                    orders[length-i-1] = tempOrder;
                }
            }
        }
        else if (side == Side.SELL && length > 1){
            for(uint i = 1; i <= length-1; i++){
                if(orders[length-i].price <= orders[length-i-1].price){
                    Order memory tempOrder =  orders[length-i];
                    orders[length-i] = orders[length-i-1];
                    orders[length-i-1] = tempOrder;
                }
            }
        }

        nextOrderId++;

    }

    function createMarketOrder(Side side, bytes32 ticker, uint amount) tokenExist(ticker) public {
        uint orderBookSide;
        if(side == Side.BUY){
            orderBookSide = 1;
        }
        if(side == Side.SELL){
            require(balances[msg.sender][ticker] >= amount);
            orderBookSide = 0;
        }

        Order[] storage orders = orderBook[ticker][orderBookSide];

        uint totalFilled = 0;

        for (uint i = 0; i < orders.length && totalFilled < amount; i++) {
            // how much we can fill from order[i]
            uint amountOrder = orders[i].amount;
            uint price = orders[i].price;
            if(side == Side.BUY){
                uint iter = 0;
                while (balances[msg.sender]["ETH"] < amountOrder.sub(iter).mul(price)){
                    iter++;
                }

                totalFilled += amountOrder.sub(iter);
                require(totalFilled != 0, "Not enough ETH to fill buy Market Order");
                if(iter == 0){
                    orders[i].filled = 1;
                }
            }
            else {
                if(amountOrder > amount){
                    totalFilled = amount;
                }
                else{
                    totalFilled += amountOrder;
                    orders[i].filled = 1;
                }
            }

            // Execute Trade & Shift balances between buyer / seller
            if (orders[i].filled == 0){
                orders[i].amount -= totalFilled;
            }

            
            if(side == Side.BUY){   
                require(balances[msg.sender]["ETH"] >= totalFilled.mul(price), "Not enough ETH to fill Market Order");
                balances[msg.sender]["ETH"] = balances[msg.sender]["ETH"].sub(totalFilled.mul(price));
                balances[orders[i].trader][ticker] = balances[orders[i].trader][ticker].sub(totalFilled);
                balances[msg.sender][ticker] = balances[msg.sender][ticker].add(totalFilled); 
                balances[orders[i].trader]["ETH"] = balances[orders[i].trader]["ETH"].add(totalFilled.mul(price));
            }
            else{
                balances[msg.sender][ticker] = balances[msg.sender][ticker].sub(totalFilled);
                balances[orders[i].trader]["ETH"] = balances[orders[i].trader]["ETH"].sub(totalFilled.mul(price));
                balances[msg.sender]["ETH"] = balances[msg.sender]["ETH"].add(totalFilled.mul(price));
                balances[orders[i].trader][ticker] = balances[orders[i].trader][ticker].add(totalFilled);
            }   

        }

        // loop through the order book and remove 100% filled orders
        while(orders.length > 0 && orders[0].filled == 1) {
            for (uint index = 0; index < orders.length.sub(1); index++){
                orders[index] = orders[index+1];
                }
            orders.pop();
        }
    }
        
}