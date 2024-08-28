// *************************************************************************
//                              SIGNATORY COMPONENT
// *************************************************************************
#[starknet::component]
pub mod SignatoryComponent {
    // *************************************************************************
    //                              IMPORTS
    // *************************************************************************
    use starknet::{
        get_caller_address, get_contract_address, ContractAddress
    };
    use token_bound_accounts::components::account::account::AccountComponent;
    use token_bound_accounts::components::account::account::AccountComponent::InternalImpl;

    // *************************************************************************
    //                              STORAGE
    // *************************************************************************
    #[storage]
    pub struct Storage {}

    // *************************************************************************
    //                              PRIVATE FUNCTIONS
    // *************************************************************************
    #[generate_trait]
    pub impl Private<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Account: AccountComponent::HasComponent<TContractState>
    > of PrivateTrait<TContractState> {
        /// @notice implements a simple signer validation where only NFT owner is a valid signer.
        /// @param signer the address to be validated
        fn _base_signer_validation(self: @ComponentState<TContractState>, signer: ContractAddress) -> bool {
            let account = get_dep_component!(self, Account);
            let (contract_address, token_id, _) = account._get_token();

            // get owner
            let owner = account
                ._get_owner(contract_address, token_id);

            // validate
            if (signer == owner) {
                return true;
            } else {
                return false;
            }
        }

        /// @notice implements a signer validation where both NFT owner and the root owner (for nested accounts) are valid signers.
        /// @param signer the address to be validated
        fn _base_and_root_signer_validation(self: @ComponentState<TContractState>, signer: ContractAddress) -> bool {
            let account = get_dep_component!(self, Account);
            let (contract_address, token_id, _) = account._get_token();

            // get owner
            let owner = account
                ._get_owner(contract_address, token_id);
            // get root owner
            let root_owner = account
                ._get_root_owner(contract_address, token_id);

            // validate
            if (signer == owner) {
                return true;
            } 
            else if(signer == root_owner) {
                return true;
            }
            else {
                return false;
            }
        }

        /// @notice implements a more complex signer validation where NFT owner, root owner, and permissioned addresses are valid signers.
        /// @param signer the address to be validated
        fn _permissioned_signer_validation(self: @ComponentState<TContractState>, signer: ContractAddress) -> bool {
            true
        }
    }
}
