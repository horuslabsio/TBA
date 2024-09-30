// *************************************************************************
//                              LOCKABLE INTERFACE
// *************************************************************************
#[starknet::interface]
pub trait ILockable<TContractState> {
    fn lock(ref self: TContractState, lock_until: u64);
    fn is_locked(self: @TContractState) -> (bool, u64);
}
