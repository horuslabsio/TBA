use starknet::account::Call;

#[starknet::interface]
pub trait IExecutable<TContractState> {
    fn _execute(ref self: TContractState, calls: Array<Call>) -> Array<Span<felt252>>;
}
