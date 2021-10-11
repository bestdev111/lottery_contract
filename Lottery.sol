pragma solidity >=0.7.0 <0.9.0;

contract Lottery {
    
    // Contract owner
    address payable private owner;

    // Current ticket price
    uint256 private ticketPrice;
    
    // Currently bought tickets
    address[] private tickets;

    // Ticket counters to track multiple buys
    mapping(address => uint8) private ticketCounts;
    uint256 private lastDrawTime;

    // Owner change event
    event OwnerSet(address indexed oldOwner, address indexed newOwner);
    
    // Lottery draw event
    event Draw(uint256 newTicketPrice);
    
    modifier isOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }
    
    constructor() {
        ticketPrice = 0;
        lastDrawTime = 0;
        owner = payable(msg.sender);
        emit OwnerSet(address(0), owner);
    }

    // Changes contract owner
    function changeOwner(address newOwner) public isOwner {
        emit OwnerSet(owner, newOwner);
        owner = payable(newOwner);
    }

    // Returns contract owner
    function getOwner() external view returns (address) {
        return owner;
    }
    
    // Returns current ticket price
    function getTicketPrice() external view returns (uint256) {
        return ticketPrice;
    }
    
    // Returns ticket count for an address
    function getTicketCount(address holder) external view returns (uint256) {
        return ticketCounts[holder];
    }
    
    // Returns last draw time
    function getLastDrawTime() external view returns (uint256) {
        return lastDrawTime;
    }

    // Returns next draw time (timelock period end)    
    function getNextDrawTime() external view returns (uint256) {
        return lastDrawTime + 36 hours;
    }
    
    // RNG, on-chain timestamp based
    function random(uint256 modulo) private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty)))%modulo;
    }
    
    // Helper function for lottery draw process
    function swapTickets(uint256 i, uint256 j) private {
        address temp = tickets[i];
        tickets[i] = tickets[j];
        tickets[j] = temp;
    }
    
    // Buys a ticket. This is called from user wallet
    function buyTicket() public payable {
        require(msg.value == ticketPrice, "Incorrect ticket price");
        require(ticketCounts[msg.sender] < 10, "Maximum 10 tickets per wallet are allowed");
        
        owner.transfer(msg.value / 20);
        tickets.push(msg.sender);
        ticketCounts[msg.sender]++;
    }
    
    // Performs a lottery draw and sets a new ticket price. This is called by backend every 36h
    function draw(uint256 newTicketPrice) public {
        require(lastDrawTime == 0 || lastDrawTime + 36 hours - 5 minutes <= block.timestamp, "Timelock has not yet expired");
        
        if (tickets.length > 0) {
            uint256 totalPool = tickets.length * (ticketPrice - ticketPrice / 20);
            uint256 winnerCount = (tickets.length - 1) / 4;
            uint256 jackpot = totalPool / 10;
            uint256 bigWinPool = ((totalPool - totalPool / 10) * 55) / 90;
            uint256 smallWinPool = totalPool - totalPool / 10 - bigWinPool;
            uint256 bigWin = bigWinPool / winnerCount;
            uint256 smallWin = smallWinPool / winnerCount;
            
            // Serving jackpot
            uint256 index = random(tickets.length);
            address jackpotWinner = tickets[index];
            payable(jackpotWinner).transfer(jackpot);
            swapTickets(0, index);
            
            // Serving big wins
            for (uint256 w = 0; w < winnerCount; w++) {
                index = random(tickets.length - 1 - w);
                address bigWinner = tickets[1 + w + index];
                payable(bigWinner).transfer(bigWin);
                swapTickets(1 + w, 1 + w + index);
            }
            
            // Serving small wins
            for (uint256 w = 0; w < winnerCount; w++) {
                index = random(tickets.length - 1 - winnerCount - w);
                address smallWinner = tickets[1 + winnerCount + w + index];
                payable(smallWinner).transfer(smallWin);
                swapTickets(1 + winnerCount + w, 1 + winnerCount + w + index);
            }
        }
        
        // Cleanup
        for (uint256 i = 0; i < tickets.length; i++) {
            ticketCounts[tickets[i]] = 0;
        }
        delete tickets;
        
        // Setting new timelock and a new ticket price
        lastDrawTime = block.timestamp;
        ticketPrice = newTicketPrice;
        emit Draw(newTicketPrice);
    }
}