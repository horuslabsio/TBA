use starknet::ClassHash;

#[starknet::interface]
trait IUpgradeable<TContractState> {
    fn _upgrade(ref self: TContractState, new_class_hash: ClassHash);
}
