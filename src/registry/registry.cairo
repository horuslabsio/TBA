use starknet::ContractAddress;

#[starknet::interface]
trait IRegistry<TContractState> {
    fn create_account(ref self: TContractState, implementation_hash: felt252, public_key: felt252, token_contract: ContractAddress, token_id: u256, salt: felt252);
    fn get_account(self: @TContractState, token_contract: ContractAddress, token_id: u256) -> ContractAddress;
}

#[starknet::contract]
mod Registry {
    use starknet::{ContractAddress, get_caller_address, syscalls::call_contract_syscall, class_hash::ClassHash, class_hash::Felt252TryIntoClassHash, syscalls::deploy_syscall};
    use zeroable::Zeroable;
    use traits::TryInto;
    use traits::Into;
    use option::OptionTrait;
    use array::ArrayTrait;
    
    #[storage]
    struct Storage {
        deployed_accounts: LegacyMap<(ContractAddress, u256), ContractAddress>
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
            salt: felt252,
        ) {
            assert(self.deployed_accounts.read((token_contract, token_id)).is_zero(), 'TBA_ALREADY_DEPLOYED');

            let mut constructor_calldata: Array<felt252> = ArrayTrait::new();
            constructor_calldata.append(public_key);
            constructor_calldata.append(token_contract.into());
            constructor_calldata.append(token_id.low.into());
            constructor_calldata.append(token_id.high.into());

            let class_hash: ClassHash = implementation_hash.try_into().unwrap();
            let result = deploy_syscall(class_hash, salt, constructor_calldata.span(), true);
            let (account_address, _) = result.unwrap_syscall();

            self.deployed_accounts.write((token_contract, token_id), account_address);

            self.emit(
                AccountCreated {
                    account_address,
                    token_contract,
                    token_id,
                }
            );
        }

        fn get_account(self: @ContractState, token_contract: ContractAddress, token_id: u256) -> ContractAddress {
            self.deployed_accounts.read((token_contract, token_id))
        }
    }
}