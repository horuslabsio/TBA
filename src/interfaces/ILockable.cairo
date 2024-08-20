use starknet::ContractAddress;

#[starknet::interface]
pub trait ILockable<TContractState> {
    fn lock(ref self: TContractState, lock_until: u64);
    fn is_lock(self: @TContractState) -> (bool, u64);
}
