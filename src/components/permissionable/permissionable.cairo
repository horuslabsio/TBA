#[starknet::component]
pub mod PermissionableComponent {
    // *************************************************************************
    //                              IMPORTS
    // *************************************************************************
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address};

    use token_bound_accounts::components::account::account::AccountComponent;
    use token_bound_accounts::interfaces::IAccount::IAccount;
    use token_bound_accounts::components::account::account::AccountComponent::AccountPrivateImpl;
    use openzeppelin_introspection::src5::SRC5Component;

    // *************************************************************************
    //                              STORAGE
    // *************************************************************************
    #[storage]
    pub struct Storage {
        permissions: Map<
            (ContractAddress, ContractAddress), bool
        > // <<owner, permissioned_address>, bool>
    }

    // *************************************************************************
    //                              EVENTS
    // *************************************************************************
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        PermissionUpdated: PermissionUpdated
    }

    // @notice emitted when permissions are updated for an account
    // @param owner tokenbound account owner
    // @param permissioned_address address to be given/revoked permission
    // @param has_permission returns true if user has permission else false
    #[derive(Drop, starknet::Event)]
    pub struct PermissionUpdated {
        #[key]
        pub owner: ContractAddress,
        pub permissioned_address: ContractAddress,
        pub has_permission: bool,
    }

    // *************************************************************************
    //                              ERRORS
    // *************************************************************************
    pub mod Errors {
        pub const INVALID_LENGTH: felt252 = 'Account: invalid length';
        pub const UNAUTHORIZED: felt252 = 'Account: unauthorized';
    }

    // *************************************************************************
    //                              PRIVATE FUNCTIONS
    // *************************************************************************
    #[generate_trait]
    pub impl PermissionablePrivateImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Account: AccountComponent::HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>
    > of PermissionablePrivateTrait<TContractState> {
        // @notice sets permission for an account
        // @permissioned_addresses array of addresses who's permission is to be updated
        // @param permssions permission value <true, false>
        fn _set_permission(
            ref self: ComponentState<TContractState>,
            permissioned_addresses: Array<ContractAddress>,
            permissions: Array<bool>
        ) {
            assert(permissioned_addresses.len() == permissions.len(), Errors::INVALID_LENGTH);

            // check only owner can set permissions
            let account_comp = get_dep_component!(@self, Account);
            let owner = account_comp.owner();
            assert(owner == get_caller_address(), Errors::UNAUTHORIZED);

            // update account state
            let mut account_comp_mut = get_dep_component_mut!(ref self, Account);
            account_comp_mut._update_state();

            let length = permissioned_addresses.len();
            let mut index: u32 = 0;
            while index < length {
                self
                    .permissions
                    .write((owner, *permissioned_addresses[index]), *permissions[index]);
                self
                    .emit(
                        PermissionUpdated {
                            owner: owner,
                            permissioned_address: *permissioned_addresses[index],
                            has_permission: *permissions[index]
                        }
                    );
                index += 1
            }
        }

        // @notice returns if a user has permission or not
        // @param owner tokenbound account owner
        // @param permissioned_address address to check permission for
        fn _has_permission(
            self: @ComponentState<TContractState>,
            owner: ContractAddress,
            permissioned_address: ContractAddress
        ) -> bool {
            let permission = self.permissions.read((owner, permissioned_address));
            permission
        }
    }
}
