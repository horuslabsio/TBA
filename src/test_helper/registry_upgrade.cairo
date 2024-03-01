use array::{ArrayTrait, SpanTrait};
use starknet::{account::Call, ContractAddress, ClassHash};

#[starknet::interface]
trait IUpgradedRegistry<TContractState> {
    fn create_account(
        ref self: TContractState,
        implementation_hash: felt252,
        token_contract: ContractAddress,
        token_id: u256,
        salt: felt252
    ) -> ContractAddress;
    fn get_account(
        self: @TContractState,
        implementation_hash: felt252,
        token_contract: ContractAddress,
        token_id: u256,
        salt: felt252
    ) -> ContractAddress;
    fn total_deployed_accounts(
        self: @TContractState, token_contract: ContractAddress, token_id: u256
    ) -> u8;
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
    fn version(self: @TContractState) -> u8;
}

#[starknet::contract]
mod UpgradedRegistry {
    use core::hash::HashStateTrait;
    use starknet::{
        ContractAddress, SyscallResultTrait, syscalls::call_contract_syscall, syscalls::deploy_syscall, get_caller_address, ClassHash
        };
    use pedersen::PedersenTrait;


    #[storage]
    struct Storage {
        Registry_deployed_accounts: LegacyMap<
            (ContractAddress, u256), u8
        >, // tracks no. of deployed accounts by registry for an NFT
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AccountCreated: AccountCreated,
        Upgraded: Upgraded
    }

    #[derive(Drop, starknet::Event)]
    struct AccountCreated {
        account_address: ContractAddress,
        token_contract: ContractAddress,
        token_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        class_hash: ClassHash
    }


    #[external(v0)]
    impl RegistryImpl of super::IUpgradedRegistry<ContractState> {

        fn create_account(
            ref self: ContractState,
            implementation_hash: felt252,
            token_contract: ContractAddress,
            token_id: u256,
            salt: felt252
        ) -> ContractAddress {
            let mut constructor_calldata: Array<felt252> = array![
                token_contract.into(), token_id.low.into(), token_id.high.into()
            ];

            let class_hash: ClassHash = implementation_hash.try_into().unwrap();
            let result = deploy_syscall(class_hash, salt, constructor_calldata.span(), true);
            let (account_address, _) = result.unwrap_syscall();

            let new_deployment_index: u8 = self
                .Registry_deployed_accounts
                .read((token_contract, token_id))
                + 1_u8;
            self.Registry_deployed_accounts.write((token_contract, token_id), new_deployment_index);

            self.emit(AccountCreated { account_address, token_contract, token_id, });

            account_address
        }

        fn get_account(
            self: @ContractState,
            implementation_hash: felt252,
            token_contract: ContractAddress,
            token_id: u256,
            salt: felt252
        ) -> ContractAddress {
            let constructor_calldata_hash = PedersenTrait::new(0)
                .update(token_contract.into())
                .update(token_id.low.into())
                .update(token_id.high.into())
                .update(3)
                .finalize();

            let prefix: felt252 = 'STARKNET_CONTRACT_ADDRESS';
            let account_address = PedersenTrait::new(0)
                .update(prefix)
                .update(0)
                .update(salt)
                .update(implementation_hash)
                .update(constructor_calldata_hash)
                .update(5)
                .finalize();

            account_address.try_into().unwrap()
        }

        /// @notice returns the total no. of deployed tokenbound accounts for an NFT by the registry
        /// @param token_contract the contract address of the NFT 
        /// @param token_id the ID of the NFT
        fn total_deployed_accounts(
            self: @ContractState, token_contract: ContractAddress, token_id: u256
        ) -> u8 {
            self.Registry_deployed_accounts.read((token_contract, token_id))
        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            assert(!new_class_hash.is_zero(), 'Class hash cannot be zero');
            starknet::replace_class_syscall(new_class_hash).unwrap_syscall();
            self.emit(Upgraded { class_hash: new_class_hash });
        }

        fn version(self: @ContractState) -> u8 {
            1_u8
        }
    }
}
