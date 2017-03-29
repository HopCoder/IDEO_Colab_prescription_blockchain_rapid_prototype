################################################################################
# DESCRIPTION :
# 	This is a simple proof of concept/rapid prototype for submitting
# 	prescriptions from a provider to a pharmacy via blockchain.  How it works is
# 	a provider will sign in (create an account on the block chain with key pairs
# 	and such) and create a new asset (which will represent a prescription).  The
# 	asset then gets assigned to the pharmacy in quantity:
#
# 	    amount_in_the_prescription x (number_of_refills + 1)
#
# 	The provider is able to query the blockchain to see all past prescriptions
# 	for a patient (as a unique patient identifier is part of the asset
# 	definition).  The pharmacy is able to query for all prescriptions sent its
# 	way.  The pharmacy then retires a certain amount of the asset (or the amount
# 	that the patient filled, which will generally be the amount in the asset
# 	definition).  Any provider can go in and see how much of an asset has been
# 	retired and how much is still in circulation leading to a better record and
# 	patient care.
#
# 	This script can be used to simulate a simple interface for a pharmacy or a
# 	provider and matches our workflow diagram.  Run the script twice in two
# 	terminals, select provider in one and pharmacy in the other, and you should
# 	be able to complete this workflow using the prompts.
#
# REQUIREMENTS:
#   Chain Core must be running and the chain core ruby SDK must be installed.
#   See https://chain.com/ for more details.
#
# AUTHOR :    M. Ryan Fredericks        START DATE :    3/29/2017
################################################################################
require 'chain'

chain = Chain::Client.new

# Simple create an asset in the block chain
def create_asset(key, chain, definition)
    return chain.assets.create(
        definition: definition,
        root_xpubs: [key.xpub],
        quorum: 1
    )
end

# Simple new account creation in the blockchain
def create_account(key, name, chain)
    chain.accounts.create(
        alias: name,
        root_xpubs: [key.xpub],
        quorum: 1
    )
end

# Takes in all the key drug information as well as a providers key and signer
# and creates a prescription and sends it off to a pharmacy.
def prescribe(key, drug, amount, patient, chain, signer, strength, route, refills, frequency, pharmacy, provider)
    # snippet issue
    definition = {
        prescribed_by: provider,
        patient_id: patient,
        medication: drug,
        strength: strength,
        frequency: frequency,
        route: route,
        refills: refills,
        quantity: amount
    }
    prescription = create_asset(key, chain, definition)
    # Issue the prescription to the pharmacy
    issuance = chain.transactions.build do |b|
        b.issue asset_id: prescription.id, amount: amount*(refills+1)
        b.control_with_account(
            account_alias: pharmacy,
            asset_id: prescription.id,
            amount: amount*(refills+1)
        )
    end

    chain.transactions.submit(signer.sign(issuance))
end


# Simple transaction builder to retire - signaling filling a script
def fill(asset_id, amount, pharmacy, chain)
    return chain.transactions.build do |b|
        b.spend_from_account(
            account_alias: pharmacy,
            asset_id: asset_id,
            amount: amount
        )
        b.retire asset_id: asset_id, amount: amount
    end
end

# When a provider sees a patient, we want to know what prescriptions they have
# filled and what they have outstanding.  If they have 3 refills left, we might
# not need to prescribe the same drug.
def get_patient(patient, chain)
    # Query assets that meet a definition for a specific patient.
    chain.assets.query(
        filter: 'definition.patient_id=$1',
        filter_params: [patient],
    ).each do |asset|
        # For now just print out the id and definition (not great).
        puts "blockchain assets #{asset.id}"
        puts "prescription: #{asset.definition}"
        # here we try to take the asset definition and get any prescriptions
        # that have been filled
        begin
            # Query any transactions on a specific prescription
            chain.transactions.query(
                # the prescription id is the asset ID and retired assets are
                # filled.
                filter: 'inputs(asset_id=$1) AND outputs(type=$2)',
                filter_params: [asset.id, 'retire'],
            ).each do |tx|
                # For each retirement transaction we have filled part of a
                # prescription, however, each output includes the control part,
                # we only want the retire part.
                tx.outputs.each do |output|
                    if output.type == 'retire'
                        puts "filled #{output.amount}"
                    end
                end
            end
        rescue
        end
        begin
            # Also simply query and output any unfilled prescriptions as
            # balances sitting with pharmacies
            puts "amount outstanding #{chain.balances.query(
                filter: 'asset_id=$1',
                filter_params: [asset.id],
            ).first.amount}"
        rescue
        end
    end
end

# Function to query the blockchain for current balances.  Useful for pharmacies
# that are sent prescriptions for certain patients and want to fill (at least
# part of) that prescription.
def get_balance(chain, pharmacy_name)
    chain.balances.query(
        filter: 'account_alias=$1',
        filter_params: [pharmacy_name],
    ).each do |b|
        # We're just going to print out each prescription here. Pretty bad
        # practice, but its a "rapid" prototype.
        puts "Prescription ID: #{b.sum_by['asset_id']}: #{b.amount}"
        # Each prescription is an asset and is defined in the asset definition.
        # That means we can easily get this definition from the balance.
        chain.assets.query(
            filter: 'id=$1',
            filter_params: [b.sum_by['asset_id']],
        ).each do |asset|
            puts "#{asset.definition}"
        end
    end
end

# Add a new key to the blockchain (right now not doing storage/management)
key = chain.mock_hsm.keys.create
signer = Chain::HSMSigner.new
signer.add_key(key, chain.mock_hsm.signer_conn)

# We have 2 types of people, a pharmacy to fill prescriptions and a provider to
# write them
person = gets.chomp
if person == "pharmacy"
    puts 'input name'
    name = gets.chomp
    create_account(key, name, chain)
    while 1
        puts 'view or fill'
        action = gets.chomp
        if action == 'view'
            get_balance(chain, name)
        elsif action == 'fill'
            puts 'input amount'
            amount = gets.chomp().to_i
            puts 'input prescription id'
            id = gets.chomp()
            # build a transaction object to retire an asset
            retirement = fill(id, amount, name, chain)
            chain.transactions.submit(signer.sign(retirement))
        end
    end
elsif person == "provider"
    puts 'input name'
    name = gets.chomp
    create_account(key, name, chain)
    while 1
        puts 'view a patient info'
        patient = gets.chomp
        while 1
            puts 'view or prescribe patient, or go back'
            action = gets.chomp
            if action == 'prescribe'
                puts 'input drug name'
                drug = gets.chomp
                puts 'input strength'
                strength = gets.chomp
                puts 'input route'
                route = gets.chomp
                puts 'input frequency'
                frequency = gets.chomp
                puts 'input pharmacy'
                pharmacy = gets.chomp
                puts 'input refills'
                refills = gets.chomp().to_i
                puts 'input amount'
                amount = gets.chomp().to_i
                prescribe(key, drug, amount, patient, chain, signer, strength, route, refills, frequency, pharmacy, name)
            elsif action == 'view'
                get_patient(patient, chain)
            elsif action == 'back'
                break
            end
        end
    end
end

