// *************************************************************************
//                              SIGNER VALIDATION INTERFACE
// *************************************************************************
use starknet::ContractAddress;

#[starknet::interface]
pub trait ISignatory<TContractState> {
    fn is_valid_signer(self: @TContractState, signer: ContractAddress) -> bool;
}
