use core::array::SpanTrait;
use starknet::ContractAddress;

#[starknet::interface]
trait IRegistry<TContractState> {
    fn create_account(ref self: TContractState, implementation_hash: felt252, public_key: felt252, token_contract: ContractAddress, token_id: u256);
    fn get_account(self: @TContractState, implementation_hash: felt252, public_key: felt252, token_contract: ContractAddress, token_id: u256) -> ContractAddress;
    fn total_deployed_accounts(self: @TContractState, token_contract: ContractAddress, token_id: u256) -> u8;
}

#[starknet::interface]
trait IERC721<TContractState> {
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn transfer_from(ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn safe_transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256, data: Span<felt252>
    );
    fn approve(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(self: @TContractState, owner: ContractAddress, operator: ContractAddress) -> bool;
    // IERC721Metadata
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn token_uri(self: @TContractState, token_id: u256) -> felt252;
}

#[starknet::contract]
mod Registry {
    use starknet::{ContractAddress, get_caller_address, syscalls::call_contract_syscall, class_hash::ClassHash, class_hash::Felt252TryIntoClassHash, syscalls::deploy_syscall};
    use zeroable::Zeroable;
    use traits::TryInto;
    use traits::Into;
    use option::OptionTrait;
    use array::ArrayTrait;
    use array::SpanTrait;

    use super::IERC721DispatcherTrait;
    use super::IERC721Dispatcher;

    #[storage]
    struct Storage {
        registry_deployed_accounts: LegacyMap<(ContractAddress, u256), u8>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AccountCreated: AccountCreated
    }

    #[derive(Drop, starknet::Event)]
    struct AccountCreated {
        account_address: ContractAddress,
        token_contract: ContractAddress,
        token_id: u256,
    }

    #[external(v0)]
    impl IRegistryImpl of super::IRegistry<ContractState> {
        fn create_account(
            ref self: ContractState,
            implementation_hash: felt252,
            public_key: felt252,
            token_contract: ContractAddress,
            token_id: u256,
        ) {
            let owner = IERC721Dispatcher { contract_address: token_contract }.owner_of(token_id);
            assert(owner == get_caller_address(), 'CALLER_IS_NOT_OWNER');

            let mut constructor_calldata: Array<felt252> = ArrayTrait::new();
            constructor_calldata.append(public_key);
            constructor_calldata.append(token_contract.into());
            constructor_calldata.append(token_id.low.into());
            constructor_calldata.append(token_id.high.into());

            let class_hash: ClassHash = implementation_hash.try_into().unwrap();
            let salt = pedersen(token_contract.into(), token_id.low.into());
            let result = deploy_syscall(class_hash, salt, constructor_calldata.span(), true);
            let (account_address, _) = result.unwrap_syscall();

            let no_of_deployed_accounts: u8 = self.registry_deployed_accounts.read((token_contract, token_id));
            self.registry_deployed_accounts.write((token_contract, token_id), no_of_deployed_accounts + 1_u8);

            self.emit(
                AccountCreated {
                    account_address,
                    token_contract,
                    token_id,
                }
            );
        }

        fn get_account(self: @ContractState, implementation_hash: felt252, public_key: felt252, token_contract: ContractAddress, token_id: u256) -> ContractAddress {
            let mut constructor_calldata: Array<felt252> = ArrayTrait::new();
            constructor_calldata.append(public_key);
            constructor_calldata.append(token_contract.into());
            constructor_calldata.append(token_id.low.into());
            constructor_calldata.append(token_id.high.into());
            
            let salt = pedersen(token_contract.into(), token_id.low.into());
            let constructor_calldata_hash = self.array_hashing(constructor_calldata.span());
            let account_address = pedersen(
                'STARKNET_CONTRACT_ADDRESS',
                0,
                salt,
                implementation_hash,
                constructor_calldata_hash
            );

            account_address.try_into().unwrap()
        }

        fn total_deployed_accounts(self: @ContractState, token_contract: ContractAddress, token_id: u256) -> u8 {
            self.registry_deployed_accounts.read((token_contract, token_id))
        }
    }

    #[generate_trait]
    impl RegistryHelperImpl of RegistryHelperTrait {
        fn array_hashing(self: @ContractState, array: Span<felt252>) -> felt252 {
            let mut array = array;
            let mut array_hash: felt252 = 0;
            
            loop {
                match array.pop_front() {
                    Option::Some(item) => {
                        array_hash = pedersen(array_hash, *item);
                    },
                    Option::None(_) => {
                        break array_hash;
                    }
                };
            }
        }
    }
}