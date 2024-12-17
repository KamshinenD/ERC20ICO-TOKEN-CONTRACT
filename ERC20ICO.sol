// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.9.0;

interface ERC20Interface{
    function totalSupply() external view returns(uint);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function transfer(address to, uint token) external returns (bool success);


    function allowance (address tokenOwner, address spender) external view returns (uint remaining);
    function approve(address spender, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}


contract KamToken is ERC20Interface{
    string public name= "Kam aToken";
    string public symbol= "KMT";
    uint public decimals=0; //18 is the usual decimal
    uint public override  totalSupply;

    address public founder;
    mapping (address=> uint) public balances;
    //eg balances[0x237638K78]=100;

    mapping(address=>mapping(address=> uint)) allowed;

  //eg  //0x111...(owner) allows 0x222...(spender) to withdraw 100 tokens from owner
    //allowed[0x111][0x222]=100;

    constructor(){
        totalSupply=1000000;
        founder=msg.sender;
        balances[founder]= totalSupply;
    }

    function balanceOf(address tokenOwner) public view override  returns (uint balance){
        return balances[tokenOwner];
    }

    function transfer (address to, uint tokens) public virtual  override returns(bool success){
        require(balances[msg.sender]>=tokens, "Insufficient funds");

        balances[to] +=tokens;
        balances[msg.sender] -=tokens;
        emit Transfer(msg.sender, to, tokens);

        return true;
    }

    function allowance(address tokenOwner, address spender) view public override returns(uint){
        return allowed[tokenOwner][spender];
    }

     modifier onlyOwner(){
        require(msg.sender==founder, "Only founder can call this function");
        _;
    }

        function approve(address spender, uint tokens) public onlyOwner override returns (bool success){
            require(balances[msg.sender]>=tokens, "insufficient funds");
            require(tokens>0, "token must be greater than 0");

            allowed[msg.sender][spender]=tokens;
            emit Approval(msg.sender, spender, tokens);
            return true;
        }

    function transferFrom(address from, address to, uint tokens) public virtual  override returns (bool success){
       require(allowed[from][msg.sender]>=tokens, "You can't send more than you are allowed to"); //the tokens that the allowed sender is allowed to send (as defined by the owner) is greater or equals to what he is sending
    //technically, sender cannot transfer tokens from owners wallet that are more than the quantity he is allowed to send
    //from is the owner of the contract, address is the receiver, msg.sender is the sender and tokens is the amount sender is sending to recipient
        require(balances[from]>=tokens, "Owner has insufficient funds"); //owner has enough tokens

        balances[from]-=tokens;
        allowed[from][msg.sender]-=tokens; //amount sender is allowed to send reduces by the number of tokens he has sent
        balances[to]+=tokens;

        emit Transfer(from, to, tokens);
        return true;
    }


}


contract KamTokenICO is KamToken{
    address public admin;
    address payable public deposit;
    uint tokenPrice= 0.001 ether; // 1KMT= 0.001ETH OR 1 ETH = 1000 KMT
    uint public hardCap= 300 ether;
    uint public raisedAmount;
    // uint public saleStart= block.timestamp + (60*60); //ico starts in 1hour time
    uint public saleStart= block.timestamp; //ico starts immediately contract is deployed
    uint public saleEnd= block.timestamp +(60*60*24*7); //ico ends in one week(7 days)
    uint public tokenTradeStarts= saleEnd +(60*60*24*7); //tokens can only be sold one week after sales end so investors won't sell and dump cos the price will go down.
    uint public maxInvestment = 5 ether;
    uint public minInvestment = 0.1 ether;
    enum State {beforeStart, running, afterEnd, halted}
    State public icoState;

    constructor(address payable _deposit){
        deposit= _deposit;
        admin= msg.sender;
        icoState= State.beforeStart;   
    }

    modifier  onlyAdmin(){
        require(msg.sender== admin, "Only admin is allowed to do this");
        _;
    }

    function suspendIco() public onlyAdmin{
        icoState= State.halted;
    }

    function resumeIco() public onlyAdmin{
        icoState= State.running;
    }

    function changeDepositAddress(address payable newDeposit) public onlyAdmin{
        deposit=newDeposit;
    }

    function getCurrentIcoState() public view returns(State) {
        if(icoState == State.halted){
        return State.halted;
        } else if (block.timestamp <saleStart){
            return State.beforeStart;
        } else if (block.timestamp>= saleStart && block.timestamp<=saleEnd){
            return State.running;
        } else{
            return State.afterEnd;
        }
    }

    event Invest(address investor, uint value, uint tokens);

    function invest()payable public returns(bool){
        icoState= getCurrentIcoState();
        require(icoState == State.running, "ICO is not running");
        require(msg.value>=minInvestment && msg.value <=maxInvestment, "investment must be within the investment amount");
        raisedAmount += msg.value;
        require(raisedAmount<=hardCap, "investment will make hard cap exceed the allowed cap amount");

        uint tokens= msg.value/tokenPrice; //number of KMT tokrens the user will get
        balances[msg.sender] +=tokens; // we are adding to the KMT tokens the the sender already has. don't forget, he is investing ETH and getting KMT as a reward
        balances[founder] -= tokens; // KMT tokens are removed from founder and credited to the sender 
        deposit.transfer(msg.value);
        emit Invest(msg.sender, msg.value, tokens);   
        return true;
    }

    receive () payable external{
        invest();
    }

      function transfer (address to, uint tokens) public override returns(bool success){
            require(block.timestamp > tokenTradeStarts, "Trades are yet to start for token");
            KamToken.transfer(to, tokens);
            // super.transfer(to, tokens); //does same thing as line above
            return true;
       }


        function transferFrom(address from, address to, uint tokens) public override returns (bool success){
                require(block.timestamp > tokenTradeStarts, "Trades are yet to start for token");
                KamToken.transferFrom(from, to, tokens);
                super.transferFrom(from, to, tokens); //does same thing as line above. since this contract (ICO) has it's base in KamToken contract.
                return true;
        }

        function burn() public returns (bool){
            icoState=getCurrentIcoState();
            require(icoState == State.afterEnd);
            balances[founder]=0;
            return true;
        }

}
