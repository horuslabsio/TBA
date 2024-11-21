#[starknet::component]
pub mod SignatoryComponent {
    // *************************************************************************
    //                              IMPORTS
    // *************************************************************************
    use starknet::ContractAddress;
    use token_bound_accounts::components::account::account::AccountComponent;
    use token_bound_accounts::components::account::account::AccountComponent::AccountPrivateImpl;
    use token_bound_accounts::components::account::account::AccountComponent::AccountImpl;

    use token_bound_accounts::components::permissionable::permissionable::PermissionableComponent;
    use token_bound_accounts::components::permissionable::permissionable::PermissionableComponent::PermissionablePrivateImpl;
    use token_bound_accounts::interfaces::ISRC6::{ISRC6Dispatcher, ISRC6DispatcherTrait};

    use openzeppelin::introspection::src5::SRC5Component;

    // *************************************************************************
    //                              STORAGE
    // *************************************************************************
    #[storage]
    pub struct Storage {}

    // *************************************************************************
    //                              ERRORS
    // *************************************************************************
    pub mod Errors {
        pub const INV_SIG_LEN: felt252 = 'Account: invalid sig length';
        pub const UNAUTHORIZED: felt252 = 'Account: invalid signer';
        pub const INVALID_SIGNATURE: felt252 = 'Account: invalid signature';
    }

    // *************************************************************************
    //                              PRIVATE FUNCTIONS
    // *************************************************************************
    #[generate_trait]
    pub impl SignatoryPrivateImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Account: AccountComponent::HasComponent<TContractState>,
        impl Permissionable: PermissionableComponent::HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>
    > of SignatoryPrivateTrait<TContractState> {
        /// @notice implements a simple signer validation where only NFT owner is a valid signer.
        /// @param signer the address to be validated
        fn _base_signer_validation(
            self: @ComponentState<TContractState>, signer: ContractAddress
        ) -> bool {
            let account = get_dep_component!(self, Account);
            let owner = account.owner();

            // validate
            if (signer == owner) {
                return true;
            } else {
                return false;
            }
        }

        /// @notice implements a more complex signer validation where NFT owner, root owner, and
        /// permissioned addresses are valid signers.
        /// @param signer the address to be validated
        fn _permissioned_signer_validation(
            self: @ComponentState<TContractState>, signer: ContractAddress
        ) -> bool {
            let account = get_dep_component!(self, Account);
            let owner = account.owner();

            // check if signer has permissions
            let permission = get_dep_component!(self, Permissionable);
            let is_permissioned = permission._has_permission(owner, signer);

            // validate
            if (signer == owner) {
                return true;
            } else if (is_permissioned) {
                return true;
            } else {
                return false;
            }
        }

        /// @notice used for signature validation
        /// @param hash The message hash
        /// @param signature The signature to be validated
        fn _is_valid_signature(
            self: @ComponentState<TContractState>, hash: felt252, signature: Span<felt252>
        ) -> felt252 {
            let account = get_dep_component!(self, Account);
            let owner = account.owner();

            // validate signature length
            let signature_length = signature.len();
            assert(signature_length == 2_u32, Errors::INV_SIG_LEN);

            // validate
            let owner_account = ISRC6Dispatcher { contract_address: owner };
            if (owner_account.is_valid_signature(hash, signature) == starknet::VALIDATED) {
                return starknet::VALIDATED;
            } else {
                return Errors::INVALID_SIGNATURE;
            }
        }
    }
}
