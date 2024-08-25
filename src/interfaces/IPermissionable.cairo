use starknet::ContractAddress;

#[starknet::interface]
pub trait IPermissionable<TContractState> {
    fn set_permission(
        ref self: TContractState,
        permission_addresses: Array<ContractAddress>,
        permissions: Array<bool>
    );
    fn has_permission(self: @TContractState, permission_addresses: ContractAddress) -> bool;
}

