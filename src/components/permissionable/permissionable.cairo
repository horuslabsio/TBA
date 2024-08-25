// permissionable component
// *************************************************************************
//                              PERMISSIONABLE COMPONENT
// *************************************************************************
#[starknet::component]
pub mod PermissionableComponent {
    // *************************************************************************
    //                              IMPORTS
    // *************************************************************************

    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use token_bound_accounts::components::account::account::AccountComponent;
    use token_bound_accounts::interfaces::IAccount::{IAccount, IAccountDispatcherTrait};
    use token_bound_accounts::components::account::account::AccountComponent::InternalImpl;
    use token_bound_accounts::interfaces::IPermissionable::{
        IPermissionable, IPermissionableDispatcher, IPermissionableDispatcherTrait
    };


    #[storage]
    pub struct Storage {
        permissions: Map<ContractAddress, (ContractAddress, bool)> // <owner => <caller, bool>>
    }

    // *************************************************************************
    //                              ERRORS
    // *************************************************************************
    pub mod Errors {
        pub const UNAUTHORIZED: felt252 = 'Permission: unauthorized';
        pub const NOT_OWNER: felt252 = 'Permission: Not Account Owner';
        pub const INVALID_LENGHT: felt252 = 'Permission: Invalid Length';
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        PermissionUpdated: PermissionUpdated
    }


    #[derive(Drop, starknet::Event)]
    pub struct PermissionUpdated {
        #[key]
        pub owner: ContractAddress,
        pub caller: ContractAddress,
        pub has_permission: bool,
    }


    // *************************************************************************
    //                              EXTERNAL FUNCTIONS
    // *************************************************************************
    #[embeddable_as(PermissionableImpl)]
    pub impl Permissionable<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Account: AccountComponent::HasComponent<TContractState>
    > of IPermissionable<ComponentState<TContractState>> {
        fn set_permission(
            ref self: ComponentState<TContractState>,
            permission_addresses: Array<ContractAddress>,
            permissions: Array<bool>
        ) {
            let account_comp = get_dep_component!(@self, Account);
            let is_valid = account_comp._is_valid_signer(get_caller_address());
            assert(is_valid, Errors::UNAUTHORIZED);

            assert(permission_addresses.len() == permissions.len(), Errors::INVALID_LENGHT);

            let owner = account_comp.owner();
            let length = permission_addresses.len();
            let mut count_index: u32 = 0;
            while count_index < length {
                self
                    .permissions
                    .write(owner, (*permission_addresses[count_index], *permissions[count_index]));
                // emit event
                self
                    .emit(
                        PermissionUpdated {
                            owner: owner,
                            caller: *permission_addresses[count_index],
                            has_permission: *permissions[count_index]
                        }
                    );
                count_index += 1
            }
        }

        fn has_permission(
            self: @ComponentState<TContractState>, permission_addresses: ContractAddress
        ) -> bool {
            true
        }
    }
}

