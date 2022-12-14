module nft9::owl_nft9{
    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    use aptos_framework::coin::{Self};
    use aptos_framework::account;
    use 0x1::table::{Self, Table};
    use aptos_token::token::{Self};
    const INVALID_SIGNER: u64 = 0;
    const INVALID_AMOUNT: u64 = 1;
    const CANNOT_ZERO: u64 = 2;
    const EINVALID_ROYALTY_NUMERATOR_DENOMINATOR: u64 = 3;
    const ESALE_NOT_STARTED: u64 = 4;
    const ESOLD_OUT:u64 = 5;
    const EMAXIMUM_MINT_OUT:u64 = 6;
    const EMINT_END:u64 = 7;


    struct BeyondOwl has key {
        collection_name: String,
        collection_description: String,
        baseuri: String,
        royalty_payee_address:address,
        royalty_points_denominator: u64,
        royalty_points_numerator: u64,
        presale_mint_time: u64,
        public_sale_mint_time: u64,
        mint_end_time: u64,
        presale_mint_price: u64,
        public_sale_mint_price: u64,
        paused: bool,
        total_supply: u64,
        minted: u64,
        token_mutate_setting:vector<bool>,
        whitelist: vector<address>,
        minted_num_info: Table<address, u64>,
        maximum_mint_num : u64,
    }
    struct ResourceInfo has key {
            source: address,
            resource_cap: account::SignerCapability
    }

    fun init_module(account:&signer){
        let collection_name = string::utf8(b"Beyond Owls");
        let collection_description = string::utf8(b"Incredible");
        let baseuri = string::utf8(b"https://gateway.pinata.cloud/ipfs/QmZ2c6P2RZA8iTjaRSbLBzkcaFwfLzQmLh75AKU35fNPjN/");
        let royalty_payee_address = signer::address_of(account);
        let royalty_points_denominator: u64 = 100;
        let royalty_points_numerator: u64 = 5;
        let presale_mint_time: u64 = 1669636800;
        let public_sale_mint_time: u64 = 1669658400;
        let mint_end_time: u64 = 1670281200;
        let presale_mint_price: u64 = 170000000;
        let public_sale_mint_price: u64 = 170000000;
        let total_supply: u64 = 3000;
        let token_mutate_setting=vector<bool>[false, false, false, false, true];
        let collection_mutate_setting=vector<bool>[false, false, false];
        let seed = vector::empty<u8>();
        vector::push_back(&mut seed, 9);
        let (_resource, resource_cap) = account::create_resource_account(account, seed);
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_cap);
        move_to<ResourceInfo>(&resource_signer_from_cap, ResourceInfo{resource_cap: resource_cap, source: signer::address_of(account)});
        let whitelist = vector::empty<address>();
        let minted_num_info = table::new<address, u64>();
        let maximum_mint_num = 3;
        move_to<BeyondOwl>(&resource_signer_from_cap, BeyondOwl{
            collection_name,
            collection_description,
            baseuri,
            royalty_payee_address,
            royalty_points_denominator,
            royalty_points_numerator,
            presale_mint_time,
            public_sale_mint_time,
            presale_mint_price,
            public_sale_mint_price,
            mint_end_time,
            total_supply,
            minted:1,
            paused:false,
            token_mutate_setting,
            whitelist,
            minted_num_info,
            maximum_mint_num
        });
        token::create_collection(
            &resource_signer_from_cap, 
            collection_name, 
            collection_description, 
            baseuri, 
            0,
            collection_mutate_setting
        );
    }
    public entry fun create_whitelist(
        account: &signer,
        collection:address,
        whitelist: vector<address>
    )acquires BeyondOwl, ResourceInfo{
        let account_addr = signer::address_of(account);
        let resource_data = borrow_global<ResourceInfo>(collection);
        assert!(resource_data.source == account_addr, INVALID_SIGNER);
        let collection_data = borrow_global_mut<BeyondOwl>(collection);
        vector::append(&mut collection_data.whitelist, whitelist);
    }
    public entry fun mint_script(
        receiver: &signer,
        collection: address
    )acquires ResourceInfo, BeyondOwl{
        let receiver_addr = signer::address_of(receiver);
        let resource_data = borrow_global<ResourceInfo>(collection);
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_data.resource_cap);
        let collection_data = borrow_global_mut<BeyondOwl>(collection);
        if(table::contains( &collection_data.minted_num_info, receiver_addr)){
            let token_minted_num = table::borrow(&collection_data.minted_num_info, receiver_addr);
            assert!(*token_minted_num < collection_data.maximum_mint_num, EMAXIMUM_MINT_OUT );
        } else{
            table::add(&mut collection_data.minted_num_info, receiver_addr, 0);
        };
        assert!(collection_data.paused == false, INVALID_SIGNER);
        assert!(collection_data.minted != collection_data.total_supply, ESOLD_OUT);
        let now = aptos_framework::timestamp::now_seconds();
        assert!(now > collection_data.presale_mint_time, ESALE_NOT_STARTED);
        // If Mint_time ended, remained tokens are burned.
        if(now > collection_data.mint_end_time){
            collection_data.total_supply = collection_data.minted - 1; 
        };
        assert!(now < collection_data.mint_end_time, EMINT_END );

        let baseuri = collection_data.baseuri;
        let owl =collection_data.minted;

        let properties = vector::empty<String>();
        string::append(&mut baseuri,num_str(owl));
        
        let token_name = collection_data.collection_name;
        string::append(&mut token_name,string::utf8(b" #"));
        string::append(&mut token_name,num_str(owl));
        string::append(&mut baseuri,string::utf8(b".json"));
        let mint_price = collection_data.public_sale_mint_price;
        token::create_token_script(
            &resource_signer_from_cap,
            collection_data.collection_name,
            token_name,
            collection_data.collection_description,
            1,
            3000,
            baseuri,
            collection_data.royalty_payee_address,
            collection_data.royalty_points_denominator,
            collection_data.royalty_points_numerator,
            collection_data.token_mutate_setting,
            properties,
            vector<vector<u8>>[],
            properties
        );
        token::opt_in_direct_transfer(receiver,true);
        coin::transfer<0x1::aptos_coin::AptosCoin>(receiver, resource_data.source, mint_price);
        token::direct_transfer_script(&resource_signer_from_cap, receiver, collection, collection_data.collection_name, token_name, 0, 1);
        collection_data.minted=collection_data.minted+1;
        let token_minted_num = table::borrow_mut(&mut collection_data.minted_num_info, receiver_addr);
        *token_minted_num = *token_minted_num + 1;
    }
    public entry fun pause_mint(
        admin: &signer,
        collection: address
    )acquires BeyondOwl, ResourceInfo{
        let account_addr = signer::address_of(admin);
        let resource_data = borrow_global<ResourceInfo>(collection);
        assert!(resource_data.source == account_addr, INVALID_SIGNER);
        let collection_data = borrow_global_mut<BeyondOwl>(collection);
        collection_data.paused = false;
    }
    public entry fun resume_mint(
        admin: &signer,
        collection:address
    )acquires BeyondOwl, ResourceInfo{
        let account_addr = signer::address_of(admin);
        let resource_data = borrow_global<ResourceInfo>(collection);
        assert!(resource_data.source == account_addr, INVALID_SIGNER);
        let collection_data = borrow_global_mut<BeyondOwl>(collection);
        collection_data.paused = true;
    }
    public entry fun update_collection(
        admin: &signer,
        royalty_points_denominator: u64,
        royalty_points_numerator: u64,
        presale_mint_time: u64,
        public_sale_mint_price: u64,
        presale_mint_price: u64,
        public_sale_mint_time: u64,
        collection:address
    )acquires BeyondOwl, ResourceInfo{
        let account_addr = signer::address_of(admin);
        let resource_data = borrow_global<ResourceInfo>(collection);
        assert!(resource_data.source == account_addr, INVALID_SIGNER);
        let collection_data = borrow_global_mut<BeyondOwl>(collection);
        assert!(royalty_points_denominator == 0, EINVALID_ROYALTY_NUMERATOR_DENOMINATOR);
        if (royalty_points_denominator>0){
            collection_data.royalty_points_denominator = royalty_points_denominator
        };
        if (royalty_points_numerator>0){
            collection_data.royalty_points_numerator = royalty_points_numerator
        };
        if (presale_mint_time>0){
            collection_data.presale_mint_time = presale_mint_time
        };
        if (public_sale_mint_time>0){
            collection_data.public_sale_mint_time = public_sale_mint_time
        };
        if (collection_data.public_sale_mint_price==0 || collection_data.presale_mint_price==0){
            if (public_sale_mint_price>0){
                collection_data.royalty_points_numerator = royalty_points_numerator
            };
            if (presale_mint_price>0){
                collection_data.royalty_points_numerator = royalty_points_numerator
            };
        };
        if (public_sale_mint_price>0){
            collection_data.presale_mint_price = presale_mint_price
        };
         if (public_sale_mint_price>0){
            collection_data.public_sale_mint_price = public_sale_mint_price
        };
    }
    fun num_str(num: u64): String{
        let v1 = vector::empty();
        while (num/10 > 0){
            let rem = num%10;
            vector::push_back(&mut v1, (rem+48 as u8));
            num = num/10;
        };
        vector::push_back(&mut v1, (num+48 as u8));
        vector::reverse(&mut v1);
        string::utf8(v1)
    }
}
