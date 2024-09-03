// *************************************************************************
//                              SIGNATORY COMPONENT
// *************************************************************************
#[starknet::component]
pub mod SignatoryComponent {
    // *************************************************************************
    //                              IMPORTS
    // *************************************************************************
    use starknet::{get_caller_address, get_contract_address, ContractAddress};
    use token_bound_accounts::components::account::account::AccountComponent;
    use token_bound_accounts::components::account::account::AccountComponent::InternalImpl;
    use token_bound_accounts::components::permissionable::permissionable::PermissionableComponent;
    use token_bound_accounts::components::permissionable::permissionable::PermissionableComponent::PermissionableImpl;
    use token_bound_accounts::interfaces::ISRC6::{ISRC6Dispatcher, ISRC6DispatcherTrait};

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
    pub impl Private<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Account: AccountComponent::HasComponent<TContractState>,
        impl Permissionable: PermissionableComponent::HasComponent<TContractState>
    > of PrivateTrait<TContractState> {
        /// @notice implements a simple signer validation where only NFT owner is a valid signer.
        /// @param signer the address to be validated
        fn _base_signer_validation(
            self: @ComponentState<TContractState>, signer: ContractAddress
        ) -> bool {
            let account = get_dep_component!(self, Account);
            let (contract_address, token_id, _) = account._get_token();

            // get owner
            let owner = account._get_owner(contract_address, token_id);

            // validate
            if (signer == owner) {
                return true;
            } else {
                return false;
            }
        }

        /// @notice implements a signer validation where both NFT owner and the root owner (for
        /// nested accounts) are valid signers.
        /// @param signer the address to be validated
        fn _base_and_root_signer_validation(
            self: @ComponentState<TContractState>, signer: ContractAddress
        ) -> bool {
            let account = get_dep_component!(self, Account);
            let (contract_address, token_id, _) = account._get_token();

            // get owner
            let owner = account._get_owner(contract_address, token_id);
            // get root owner
            let root_owner = account._get_root_owner(contract_address, token_id);

            // validate
            if (signer == owner) {
                return true;
            } else if (signer == root_owner) {
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
            let (contract_address, token_id, _) = account._get_token();

            // get owner
            let owner = account._get_owner(contract_address, token_id);
            // get root owner
            let root_owner = account._get_root_owner(contract_address, token_id);

            // check if signer has permissions
            let permission = get_dep_component!(self, Permissionable);
            let is_permissioned = permission.has_permission(owner, signer);

            // validate
            if (signer == owner) {
                return true;
            } else if (signer == root_owner) {
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
            let (contract_address, token_id, _) = account._get_token();
            let owner = account._get_owner(contract_address, token_id);
            let root_owner = account._get_root_owner(contract_address, token_id);

            let signature_length = signature.len();
            assert(signature_length == 2_u32, Errors::INV_SIG_LEN);

            let owner_account = ISRC6Dispatcher { contract_address: owner };
            let root_owner_account = ISRC6Dispatcher { contract_address: root_owner };

            // validate
            if (owner_account.is_valid_signature(hash, signature) == starknet::VALIDATED) {
                return starknet::VALIDATED;
            } else if (root_owner_account
                .is_valid_signature(hash, signature) == starknet::VALIDATED) {
                return starknet::VALIDATED;
            } else {
                return Errors::INVALID_SIGNATURE;
            }
        }
    }
}
