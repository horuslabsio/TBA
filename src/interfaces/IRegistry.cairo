use starknet::ContractAddress;

#[starknet::interface]
trait IRegistry<TContractState> {
    fn create_account(
        ref self: TContractState,
        implementation_hash: felt252,
        token_contract: ContractAddress,
        token_id: u256,
        salt: felt252,
        chain_id: felt252
    ) -> ContractAddress;

    fn get_account(
        self: @TContractState,
        implementation_hash: felt252,
        token_contract: ContractAddress,
        token_id: u256,
        salt: felt252,
        chain_id: felt252
    ) -> ContractAddress;
}
