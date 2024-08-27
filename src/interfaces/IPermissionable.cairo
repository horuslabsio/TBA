use starknet::ContractAddress;

#[starknet::interface]
pub trait IPermissionable<TContractState> {
    fn set_permission(
        ref self: TContractState,
        permissioned_addresses: Array<ContractAddress>,
        permissions: Array<bool>
    );
    fn has_permission(
        self: @TContractState, owner: ContractAddress, permissioned_address: ContractAddress
    ) -> bool;
}

