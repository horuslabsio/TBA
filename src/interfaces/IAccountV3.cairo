use starknet::{ContractAddress, ClassHash,};


#[starknet::interface]
pub trait IAccountV3<TContractState> {
    // fn on_erc721_received(
    //     self: @TContractState,
    //     token_contract: ContractAddress,
    //     token_id: u256,
    //     calldata: Span<felt252>
    // ) -> (felt252, ByteArray);
    fn on_erc721_received(
        self: @TContractState,
        _token_contract: ContractAddress,
        _token_id: u256,
        calldata: Span<felt252>
    ) -> ByteArray;
    fn get_context(self: @TContractState) -> (ContractAddress, felt252, felt252);
}

