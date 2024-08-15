#[starknet::interface]
trait IExecutable<TContractState> {
    fn _execute(
        ref self: ComponentState<TContractState>, 
        mut calls: Array<Call>
    ) -> Array<Span<felt252>>;
}
