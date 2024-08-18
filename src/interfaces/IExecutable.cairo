// *************************************************************************
//                              EXECUTABLE INTERFACE
// *************************************************************************
use starknet::account::Call;

#[starknet::interface]
pub trait IExecutable<TContractState> {
    fn execute(ref self: TContractState, calls: Array<Call>) -> Array<Span<felt252>>;
}
