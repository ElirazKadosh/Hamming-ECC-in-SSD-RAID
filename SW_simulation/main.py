# RAID 5 Simulation with Hamming ECC and Write/Read Buffers
import time
import sys
import random

num_of_fail_disks = 0  # Number of failed disks

# Constants
NUM_DISKS = 3  # Number of disks
NUM_STRIPES = 6  # Number of stripes
BLOCK_SIZE = 12  # Size of each block in 12 bits
WRITE_BUFFER_SIZE = 100000  # Write buffer size
READ_BUFFER_SIZE = 100000  # Read buffer size

# Initialize RAID 5 disks with zeros
disks = [[[0] * BLOCK_SIZE for _ in range(NUM_STRIPES)] for _ in range(NUM_DISKS)]

# Stripe validity matrix
stripe_valid = [{"stripe_num": i, "is_valid": 1} for i in range(NUM_STRIPES)]

# Write and Read Buffers
write_buffer = [{"address": 0, "data": 0} for _ in range(WRITE_BUFFER_SIZE)]
read_buffer = [{"address": 0} for _ in range(READ_BUFFER_SIZE)]

write_buffer_count = 0  # the number of requests that write_buffer holds now
read_buffer_count = 0  # the number of requests that read_buffer holds now
write_sys_is_ready = 0  # Is the write system ready for operation
read_sys_is_ready = 1  # System is initially ready for read requests
disk_status = [1, 1, 1]  # # Disk health status array: 1 = Healthy, 0 = Failed

enable_print_write_buffer=0
enable_print_disk_state=0

# Counters for writes per disk and per block
write_count_per_disk = [0] * NUM_DISKS  # Counter per disk
write_count_per_block = [[0] * NUM_STRIPES for _ in range(NUM_DISKS)]  # Counter per block in each disk

def format_block(block):
    block_str = "".join(map(str, block))
    return " ".join(block_str[i:i + 4] for i in range(0, len(block_str), 4))

def format_address(address):
    address_str = f"{address:08b}"
    return " ".join(address_str[i:i + 4] for i in range(0, len(address_str), 4))

def format_data(data):
    data_str = f"{data:016b}"
    return " ".join(data_str[i:i + 4] for i in range(0, len(data_str), 4))

def print_red(text):
    """
    Prints the given text in bold red color.

    Parameters:
        text (str): The text to print.
    """
    print(f"\033[1;31m{text}\033[0m")

def print_disk_state():
    if enable_print_disk_state==0:
        return
    print("\n💾 Disk State:")
    print("Stripe |    Disk 0     |    Disk 1     |    Disk 2")
    print("-" * 50)
    for stripe in range(NUM_STRIPES):
        row = f"{stripe:^6}|"
        for disk in range(NUM_DISKS):
            block = disks[disk][stripe]
            formatted_block = format_block(block)
            row += f" {formatted_block:^14}|"
        print(row)
    print("-" * 50)

def print_write_buffer():
    if enable_print_write_buffer==0:
        return
    print("\n📝 Write Buffer:")
    print("Index |   Address   |       Data")
    print("-" * 35)
    for i, entry in enumerate(write_buffer):
        addr = format_address(entry['address'])
        data = format_data(entry['data'])
        print(f"{i:^5}| {addr:^12} | {data:^18}")
    print("-" * 35)
    print(f"🟦 Write Buffer Count: {write_buffer_count}/{WRITE_BUFFER_SIZE}")
    print("-" * 35)

def xor_blocks(block1, block2):
    return [b1 ^ b2 for b1, b2 in zip(block1, block2)]

def hamming_encode(data):
    encoded = [0] * 12
    encoded[2] = (data >> 7) & 1
    encoded[4] = (data >> 6) & 1
    encoded[5] = (data >> 5) & 1
    encoded[6] = (data >> 4) & 1
    encoded[8] = (data >> 3) & 1
    encoded[9] = (data >> 2) & 1
    encoded[10] = (data >> 1) & 1
    encoded[11] = data & 1

    encoded[0] = encoded[2] ^ encoded[4] ^ encoded[6] ^ encoded[8] ^ encoded[10]
    encoded[1] = encoded[2] ^ encoded[5] ^ encoded[6] ^ encoded[9] ^ encoded[10]
    encoded[3] = encoded[4] ^ encoded[5] ^ encoded[6] ^ encoded[11]
    encoded[7] = encoded[8] ^ encoded[9] ^ encoded[10] ^ encoded[11]

    return encoded

def shift_write_buffer():
    global write_buffer, write_buffer_count
    for i in range(WRITE_BUFFER_SIZE - 1):
        write_buffer[i] = write_buffer[i + 1]
    write_buffer[WRITE_BUFFER_SIZE - 1] = {"address": 0, "data": 0}  # Clear last entry

def add_write_request(address, data):
    global write_buffer_count

    new_write_request = {"address": address, "data": data}

    if write_buffer_count >= WRITE_BUFFER_SIZE:
        # Buffer is full, reject the new request
        print("❌ Write Buffer FULL. Write request REJECTED.")
    else:
        # Add new request at the end of the buffer
        write_buffer[write_buffer_count] = new_write_request
        write_buffer_count += 1
        print("✅ Write request added to buffer.")

    print_write_buffer()

def handle_write_request():
    global write_buffer_count, write_sys_is_ready, num_of_fail_disks

    if write_buffer_count > 0 and write_sys_is_ready == 1:
        write_sys_is_ready = 0  # write_sys is busy

        req = write_buffer[0]  # always the first request (FIFO)
        print(f"\n🔄 Handling Write Request: Address: {format_address(req['address'])}, "
              f"Data: {format_data(req['data'])} ({req['data']})")

        write_buffer_count -= 1

        D0 = int((req['data'] >> 8) & 0xFF)
        D1 = int(req['data'] & 0xFF)

        D0_enc = hamming_encode(D0)
        D1_enc = hamming_encode(D1)

        print(f"🔹 D0 (Upper 8 bits): {format_address(D0)} ({D0})")
        print(f"🔹 D1 (Lower 8 bits): {format_address(D1)} ({D1})")
        print(f"🔹 D0_enc: {format_block(D0_enc)} ({int(''.join(map(str, D0_enc)), 2)})")
        print(f"🔹 D1_enc: {format_block(D1_enc)} ({int(''.join(map(str, D1_enc)), 2)})")

        stripe_num = req['address'] & 0x07
        parity_disk = (stripe_num - 1) % NUM_DISKS

        if stripe_valid[stripe_num]['is_valid'] == 1:
            data_disks = [0, 1, 2]
            data_disks.remove(parity_disk)
            D0_enc_old = disks[data_disks[0]][stripe_num]
            D1_enc_old = disks[data_disks[1]][stripe_num]

            print(f"🔹 D0_enc_old: {format_block(D0_enc_old)} ({int(''.join(map(str, D0_enc_old)), 2)})")
            print(f"🔹 D1_enc_old: {format_block(D1_enc_old)} ({int(''.join(map(str, D1_enc_old)), 2)})")

            if D0_enc == D0_enc_old and D1_enc == D1_enc_old:
                print("✅ Data is identical. Skipping redundant write.")
            else:
                if num_of_fail_disks > 0:
                    handle_system_failure()
                    selective_write_to_disks(req['address'], D0_enc, D1_enc, D0_enc_old, D1_enc_old)
                else:
                    selective_write_to_disks(req['address'], D0_enc, D1_enc, D0_enc_old, D1_enc_old)
        else:
            write_to_disks(req['address'], D0_enc, D1_enc)

        shift_write_buffer()
        write_sys_is_ready = 1  # write_sys is free

def write_to_disks(address, D0_enc, D1_enc):
    stripe_num = address & 0x07  # Extract stripe number (3 LSBs of address)
    parity_disk = (stripe_num - 1) % NUM_DISKS  # Cyclic parity disk calculation

    print(f"\n🔄 Writing Data to Stripe {stripe_num}:")
    print(f"🔹 D0_enc: {format_block(D0_enc)} ({int(''.join(map(str, D0_enc)), 2)})")
    print(f"🔹 D1_enc: {format_block(D1_enc)} ({int(''.join(map(str, D1_enc)), 2)})")

    if stripe_valid[stripe_num]['is_valid'] == 0:
        print("🛡️ Stripe is INVALID. Calculating Parity (P0)...")
        P0 = xor_blocks(D0_enc, D1_enc)
        print(f"🔄 Parity (P0): {format_block(P0)} ({int(''.join(map(str, P0)), 2)})")

        if parity_disk == 0:
            disks[0][stripe_num] = P0
            disks[1][stripe_num] = D0_enc
            disks[2][stripe_num] = D1_enc

            # Update write counters
            write_count_per_disk[0] += 1
            write_count_per_disk[1] += 1
            write_count_per_disk[2] += 1

            write_count_per_block[0][stripe_num] += 1
            write_count_per_block[1][stripe_num] += 1
            write_count_per_block[2][stripe_num] += 1

        elif parity_disk == 1:
            disks[1][stripe_num] = P0
            disks[0][stripe_num] = D0_enc
            disks[2][stripe_num] = D1_enc

            # Update write counters
            write_count_per_disk[1] += 1
            write_count_per_disk[0] += 1
            write_count_per_disk[2] += 1

            write_count_per_block[1][stripe_num] += 1
            write_count_per_block[0][stripe_num] += 1
            write_count_per_block[2][stripe_num] += 1

        elif parity_disk == 2:
            disks[2][stripe_num] = P0
            disks[0][stripe_num] = D0_enc
            disks[1][stripe_num] = D1_enc

            # Update write counters
            write_count_per_disk[2] += 1
            write_count_per_disk[0] += 1
            write_count_per_disk[1] += 1

            write_count_per_block[2][stripe_num] += 1
            write_count_per_block[0][stripe_num] += 1
            write_count_per_block[1][stripe_num] += 1


        stripe_valid[stripe_num]['is_valid'] = 1
        print(f"✅ Stripe {stripe_num} marked as VALID.")

    print_disk_state()

def calculate_p0_new(D0_enc, D1_enc):
    return xor_blocks(D0_enc, D1_enc)

def handle_system_failure():
    global num_of_fail_disks
    print("\n❌ System Failure Detected! Entering recovery mode...")
    for i in range(1, 11):
        print(f"⏳ Waiting... {i} seconds")
        time.sleep(1)  # Waiting for one second
    print("🔄 Recovery attempt complete. Resetting failure count.")
    num_of_fail_disks = 0

def selective_write_to_disks(address, D0_enc, D1_enc, D0_enc_old, D1_enc_old):
    stripe_num = address & 0x07  # Stripe number
    parity_disk = (stripe_num - 1) % NUM_DISKS  # Cyclic parity disk calculation

    # Calculate new parity
    P0_new = calculate_p0_new(D0_enc, D1_enc)
    print(f"🔄 Calculated New Parity (P0_new): {format_block(P0_new)} ({int(''.join(map(str, P0_new)), 2)})")

    # Comparison between current and old values
    if D0_enc == D0_enc_old and D1_enc != D1_enc_old:
        print(f"✍️ Writing Only: P0_new ({int(''.join(map(str, P0_new)), 2)}), D1_enc ({int(''.join(map(str, D1_enc)), 2)})")
        if parity_disk == 0:
            disks[0][stripe_num] = P0_new
            disks[2][stripe_num] = D1_enc

            write_count_per_disk[0] += 1
            write_count_per_disk[2] += 1

            write_count_per_block[0][stripe_num] += 1
            write_count_per_block[2][stripe_num] += 1

        elif parity_disk == 1:
            disks[1][stripe_num] = P0_new
            disks[2][stripe_num] = D1_enc

            write_count_per_disk[1] += 1
            write_count_per_disk[2] += 1

            write_count_per_block[1][stripe_num] += 1
            write_count_per_block[2][stripe_num] += 1

        elif parity_disk == 2:
            disks[2][stripe_num] = P0_new
            disks[1][stripe_num] = D1_enc

            write_count_per_disk[0] += 1
            write_count_per_disk[1] += 1

            write_count_per_block[0][stripe_num] += 1
            write_count_per_block[1][stripe_num] += 1


    elif D1_enc == D1_enc_old and D0_enc != D0_enc_old:
        print(f"✍️ Writing Only: P0_new ({int(''.join(map(str, P0_new)), 2)}), D0_enc ({int(''.join(map(str, D0_enc)), 2)})")
        if parity_disk == 0:
            disks[0][stripe_num] = P0_new
            disks[1][stripe_num] = D0_enc

            write_count_per_disk[0] += 1
            write_count_per_disk[1] += 1

            write_count_per_block[0][stripe_num] += 1
            write_count_per_block[1][stripe_num] += 1

        elif parity_disk == 1:
            disks[1][stripe_num] = P0_new
            disks[0][stripe_num] = D0_enc

            write_count_per_disk[1] += 1
            write_count_per_disk[0] += 1

            write_count_per_block[1][stripe_num] += 1
            write_count_per_block[0][stripe_num] += 1

        elif parity_disk == 2:
            disks[2][stripe_num] = P0_new
            disks[0][stripe_num] = D0_enc

            write_count_per_disk[2] += 1
            write_count_per_disk[0] += 1

            write_count_per_block[2][stripe_num] += 1
            write_count_per_block[0][stripe_num] += 1


    else:
        print(f"✍️ Writing All: P0_new ({int(''.join(map(str, P0_new)), 2)}), "
              f"D0_enc ({int(''.join(map(str, D0_enc)), 2)}), D1_enc ({int(''.join(map(str, D1_enc)), 2)})")
        if parity_disk == 0:
            disks[0][stripe_num] = P0_new
            disks[1][stripe_num] = D0_enc
            disks[2][stripe_num] = D1_enc

            write_count_per_disk[0] += 1
            write_count_per_disk[1] += 1
            write_count_per_disk[2] += 1

            write_count_per_block[0][stripe_num] += 1
            write_count_per_block[1][stripe_num] += 1
            write_count_per_block[2][stripe_num] += 1

        elif parity_disk == 1:
            disks[1][stripe_num] = P0_new
            disks[0][stripe_num] = D0_enc
            disks[2][stripe_num] = D1_enc

            write_count_per_disk[1] += 1
            write_count_per_disk[0] += 1
            write_count_per_disk[2] += 1

            write_count_per_block[1][stripe_num] += 1
            write_count_per_block[0][stripe_num] += 1
            write_count_per_block[2][stripe_num] += 1

        elif parity_disk == 2:
            disks[2][stripe_num] = P0_new
            disks[0][stripe_num] = D0_enc
            disks[1][stripe_num] = D1_enc

            write_count_per_disk[2] += 1
            write_count_per_disk[0] += 1
            write_count_per_disk[1] += 1

            write_count_per_block[2][stripe_num] += 1
            write_count_per_block[0][stripe_num] += 1
            write_count_per_block[1][stripe_num] += 1


    # Mark stripe as valid
    stripe_valid[stripe_num]['is_valid'] = 1
    print_disk_state()

def add_read_request(address):
    global read_buffer_count

    new_read_request = {"address": address}

    if read_buffer_count >= READ_BUFFER_SIZE:
        print("❌ Read Buffer FULL. Read request REJECTED.")
    else:
        read_buffer[read_buffer_count] = new_read_request
        read_buffer_count += 1
        print(f"✅ Read request added to buffer. Address: {format_address(address)}")

    print_read_buffer()

def print_read_buffer():
    print("\n📖 Read Buffer:")
    print("Index |   Address")
    print("-" * 25)
    for i, entry in enumerate(read_buffer):
        addr = format_address(entry['address'])
        print(f"{i:^5}| {addr:^12}")
    print("-" * 25)
    print(f"🟦 Read Buffer Count: {read_buffer_count}/{READ_BUFFER_SIZE}")
    print("-" * 25)

def Hamming_check(encoded_block):
    # Calculate parity bits
    P1 = encoded_block[0] ^ encoded_block[2] ^ encoded_block[4] ^ encoded_block[6] ^ encoded_block[8] ^ encoded_block[
        10]
    P2 = encoded_block[1] ^ encoded_block[2] ^ encoded_block[5] ^ encoded_block[6] ^ encoded_block[9] ^ encoded_block[
        10]
    P4 = encoded_block[3] ^ encoded_block[4] ^ encoded_block[5] ^ encoded_block[6] ^ encoded_block[11]
    P8 = encoded_block[7] ^ encoded_block[8] ^ encoded_block[9] ^ encoded_block[10] ^ encoded_block[11]

    # Calculate the syndrome
    S = (P1 * 1) + (P2 * 2) + (P4 * 4) + (P8 * 8)


    if S == 0:
        return "No Error"
    else:
        return "SBE"

def Hamming_fix(encoded_block):
    print("🛠️ Fixing single-bit error...")
    P1 = encoded_block[0] ^ encoded_block[2] ^ encoded_block[4] ^ encoded_block[6] ^ encoded_block[8] ^ encoded_block[
        10]
    P2 = encoded_block[1] ^ encoded_block[2] ^ encoded_block[5] ^ encoded_block[6] ^ encoded_block[9] ^ encoded_block[
        10]
    P4 = encoded_block[3] ^ encoded_block[4] ^ encoded_block[5] ^ encoded_block[6] ^ encoded_block[11]
    P8 = encoded_block[7] ^ encoded_block[8] ^ encoded_block[9] ^ encoded_block[10] ^ encoded_block[11]

    # Calculate the syndrome
    S = (P1 * 1) + (P2 * 2) + (P4 * 4) + (P8 * 8)
    encoded_block[S - 1] = encoded_block[S - 1] ^ 1

    return encoded_block

def Hamming_decode(encoded_block):
    # Extract original 8 bits (positions: 2, 4, 5, 6, 8, 9, 10, 11)
    return (encoded_block[2] << 7 | encoded_block[4] << 6 | encoded_block[5] << 5 |
            encoded_block[6] << 4 | encoded_block[8] << 3 | encoded_block[9] << 2 |
            encoded_block[10] << 1 | encoded_block[11])

def RAID5_recovery():
    global disks, disk_status, num_of_fail_disks
    print("\n🛠️ Starting RAID5 Disk Recovery...")

    # Identify the failed disk
    failed_disks = [i for i, status in enumerate(disk_status) if status == 0]

    if len(failed_disks) > 1:
        while num_of_fail_disks > 0:
            print("❌ ERROR: More than one disk has failed. Recovery is impossible!")
            sys.exit("Stopping the program")
        return

    failed_disk = failed_disks[0]
    print(f"🔄 Recovering Disk {failed_disk}...")

    # Recover each stripe on the failed disk
    for stripe_num in range(NUM_STRIPES):
        healthy_disks = [i for i in range(NUM_DISKS) if i != failed_disk]
        recovered_block = xor_blocks(disks[healthy_disks[0]][stripe_num],
                                     disks[healthy_disks[1]][stripe_num])
        disks[failed_disk][stripe_num] = recovered_block
        print(f"✅ Recovered Stripe {stripe_num} on Disk {failed_disk}")

    disk_status[failed_disk] = 1  # Mark the disk as healthy after recovery
    num_of_fail_disks = disk_status.count(0)
    print(f"✅ Disk {failed_disk} successfully recovered.")
    print_disk_state()
    print("\n✅ RAID 5 System is Stable.")

def shift_read_buffer():
    global read_buffer, read_buffer_count
    for i in range(READ_BUFFER_SIZE - 1):
        read_buffer[i] = read_buffer[i + 1]
    read_buffer[READ_BUFFER_SIZE - 1] = {"address": 0}  # Clear the last value

def handle_read_request():
    global read_buffer_count, num_of_fail_disks, read_sys_is_ready, disk_status

    if read_buffer_count > 0 and read_sys_is_ready == 1:
        read_sys_is_ready = 0  # System is busy with a read operation

        req = read_buffer[0]  # Dequeue the first request
        address = req['address']
        stripe_num = address & 0x07  # Extract stripe number (3 LSBs)
        parity_disk = (stripe_num - 1) % NUM_DISKS

        print(f"\n📖 Processing Read Request at Address: {format_address(address)} (Stripe {stripe_num})")
        read_buffer_count -= 1
        # Identify disk positions
        if parity_disk == 0:
            D0_disk, D1_disk, P0_disk = 1, 2, 0
        elif parity_disk == 1:
            D0_disk, D1_disk, P0_disk = 0, 2, 1
        elif parity_disk == 2:
            D0_disk, D1_disk, P0_disk = 0, 1, 2

        # Check how many disks are healthy
        num_of_fail_disks = disk_status.count(0)

        if num_of_fail_disks > 1:
            print("❌ ERROR: Too many disk failures. System cannot recover data.")

            # Identify and print all failed disks
            failed_disks = [i for i, status in enumerate(disk_status) if status == 0]
            print(f"💥 Failed Disks: {', '.join(map(str, failed_disks))}")

            while num_of_fail_disks > 0:
                print(f"⏳ System paused due to {num_of_fail_disks} disk failures. Waiting for recovery...")
                time.sleep(1)
            return

        if num_of_fail_disks == 1:
            print("🛡️ One disk failure detected. Performing RAID5 Recovery...")
            RAID5_recovery()

        if num_of_fail_disks == 0:
            print("✅ All disks are healthy. Performing Hamming ECC check...")
            # Normal ECC check and decoding
            D0_enc = disks[D0_disk][stripe_num]
            D1_enc = disks[D1_disk][stripe_num]

            if Hamming_check(D0_enc) == "SBE":
                print("⚠️ Single-Bit Error detected in D0_enc. Correcting...")
                D0_enc = Hamming_fix(D0_enc)
                disks[D0_disk][stripe_num] = D0_enc
                print("✅ D0_enc corrected and written back.")

            if Hamming_check(D1_enc) == "SBE":
                print("⚠️ Single-Bit Error detected in D1_enc. Correcting...")
                D1_enc = Hamming_fix(D1_enc)
                disks[D1_disk][stripe_num] = D1_enc
                print("✅ D1_enc corrected and written back.")

        D0_dec = Hamming_decode(D0_enc)
        D1_dec = Hamming_decode(D1_enc)

        data = (D0_dec << 8) | D1_dec
        print(f"✅ Read Complete. Data at Address {format_address(address)}: {format_data(data)}")

        shift_read_buffer()
        read_sys_is_ready = 1

def reset_disk(disk_index):
    """
    Resets all blocks on a specific disk.
    Args:
        disk_index (int):
    """
    global disks

    if 0 <= disk_index < NUM_DISKS:
        disks[disk_index] = [[0] * BLOCK_SIZE for _ in range(NUM_STRIPES)]
        print(f"🔄 Disk {disk_index} has been reset. All blocks are now zero.")
        print_disk_state()
    else:
        print(f"❌ Invalid disk index: {disk_index}. Please provide a valid disk index (0-{NUM_DISKS - 1}).")

def simulate_single_bit_error():
    """
    Simulate a Single Bit Error (SBE) in each stripe with varying bit positions.
    """
    error_bit_position = 0  # # We will start from bit 0 and continue through each strip

    print("\n🛠️ Simulating Single Bit Error in each Stripe:")
    for stripe_num in range(NUM_STRIPES):
        parity_disk = (stripe_num - 1) % NUM_DISKS
        data_disks = [0, 1, 2]
        data_disks.remove(parity_disk)

        # # Select data disk circularly
        error_disk = data_disks[stripe_num % len(data_disks)]
        block = disks[error_disk][stripe_num]

        print(f"\n🔄 Stripe {stripe_num}: Injecting Error in Disk {error_disk}, Bit Position {error_bit_position}")
        print(f"🔹 Before Error: {format_block(block)}")

        # Flip the corresponded bit.
        block[error_bit_position % BLOCK_SIZE] ^= 1

        print(f"🔹 After Error:  {format_block(block)}")

        # Update the bit position for the next error
        error_bit_position = (error_bit_position + 1) % BLOCK_SIZE

    print("\n✅ Single Bit Error Simulation Completed.")

def simulate_single_bit_error_D0_D1():
    """
    Simulate a Single Bit Error (SBE) in both D0_enc and D1_enc for each stripe.
    """
    error_bit_position_D0 = 0  # Error bit position for D0
    error_bit_position_D1 = 1  # Error bit position for D1 (different from D0)

    print("\n🛠️ Simulating Single Bit Error in D0_enc and D1_enc for each Stripe:")
    for stripe_num in range(NUM_STRIPES):
        # Calculate parity disk
        parity_disk = (stripe_num - 1) % NUM_DISKS
        data_disks = [0, 1, 2]
        data_disks.remove(parity_disk)

        # Select disks for D0 and D1
        D0_disk = data_disks[0]
        D1_disk = data_disks[1]

        # Access to D0 and D1 blocks
        D0_block = disks[D0_disk][stripe_num]
        D1_block = disks[D1_disk][stripe_num]

        print(f"\n🔄 Stripe {stripe_num}:")

        # Creating an error in D0
        print(f"🔹 Injecting Error in Disk {D0_disk} (D0_enc), Bit Position {error_bit_position_D0}")
        print(f"   Before Error (D0): {format_block(D0_block)}")
        D0_block[error_bit_position_D0 % BLOCK_SIZE] ^= 1  # Toggle the bit
        print(f"   After Error (D0):  {format_block(D0_block)}")

        # Creating an error in D1
        print(f"🔹 Injecting Error in Disk {D1_disk} (D1_enc), Bit Position {error_bit_position_D1}")
        print(f"   Before Error (D1): {format_block(D1_block)}")
        D1_block[error_bit_position_D1 % BLOCK_SIZE] ^= 1  # Toggle the bit
        print(f"   After Error (D1):  {format_block(D1_block)}")

        # Updating bit positions
        error_bit_position_D0 = (error_bit_position_D0 + 1) % BLOCK_SIZE
        error_bit_position_D1 = (error_bit_position_D1 + 1) % BLOCK_SIZE

    print("\n✅ Single Bit Error Simulation for D0_enc and D1_enc Completed.")

def simulate_random_write_requests(num_requests):
    global write_buffer_count, write_sys_is_ready

    reset_disk(0)
    reset_disk(1)
    reset_disk(2)
    write_buffer_count = 0

    for i in range(num_requests):
        address = random.randint(0, NUM_STRIPES - 1)
        data = random.randint(0, 0xFFFF)

        add_write_request(address, data)

    while write_buffer_count > 0:
        handle_write_request()

    print("✅ Dynamic Write Simulation Completed.")

def print_write_counters():
    print("\n📊 Write Counters Summary:")
    print("Disk Write Counts:")
    for i, count in enumerate(write_count_per_disk):
        print(f"Disk {i}: {count} writes")

    print("\nBlock Write Counts per Disk:")
    for i, block_counts in enumerate(write_count_per_block):
        print(f"Disk {i}: {block_counts}")

def reset_write_counters():
    """
    Reset the write counters for disks and blocks.
    """
    global write_count_per_disk, write_count_per_block

    write_count_per_disk = [0] * NUM_DISKS

    write_count_per_block = [[0] * NUM_STRIPES for _ in range(NUM_DISKS)]

    print("🔄 Write counters have been reset.")


def simulate_mixed_write_distribution(num_requests):
    """
    Simulation of writes that are 75% writes with new information and 25% of the writes are repeated writes in block D0 or block D1 randomly.
    """
    global write_buffer_count, write_sys_is_ready

    reset_disk(0)
    reset_disk(1)
    reset_disk(2)
    write_buffer_count = 0

    previous_D0 = random.randint(0, 0xFF)
    previous_D1 = random.randint(0, 0xFF)
    previous_address = random.randint(0, 5)

    print("\n📝 Simulating Mixed Write Distribution (75% Random, 25% Pattern-Based Repeated)...")

    for i in range(1, num_requests + 1):
        if i % 4 == 0:
            # Rewrite request
            address = previous_address
            if random.random() < 0.5:
                # Change in D0, D1 remains the same
                data = (random.randint(0, 0xFF) << 8) | previous_D1
            else:
                # Change in D1, D0 remains the same
                data = (previous_D0 << 8) | random.randint(0, 0xFF)
            print(f"🔄 Repeated Write: Address: {address}, Data: {format_data(data)}")
        else:
            # Random write request
            address = random.randint(0, 5)
            data = random.randint(0, 0xFFFF)
            previous_D0 = (data >> 8) & 0xFF
            previous_D1 = data & 0xFF
            previous_address = address
            print(f"✨ Random Write: Address: {address}, Data: {format_data(data)}")

        add_write_request(address, data)

    while write_buffer_count > 0:
        handle_write_request()

    print("✅ Mixed Write Simulation Completed.")


# Main Program for RAID 5 Simulation
"""
if __name__ == "__main__":

    # System Initialization
    write_sys_is_ready = 1  # Enable write system
    read_sys_is_ready = 1   # Enable read system

    print("\n🔄 Initial RAID 5 System State:")
    print_disk_state()
    print_write_buffer()
    print_read_buffer()

    # Write for the first time to address 0x00.
    # Expectation: mark stripe 0 as valid and write all blocks
    add_write_request(0x01, 0b1010101101010010)
    print_red("\nWrite for the first time to address 0x00.")
    print_red("Expectation: mark stripe 0 valid and write all blocks")
    handle_write_request()

    # Write same data again.
    # Expectation: do not repeat the same write
    add_write_request(0x01, 0b1010101101010010)
    print_red("\nWrite same data again.")
    print_red("Expectation: do not repeat the same write")
    handle_write_request()

    # Write same upper 8-bit of data.
    # Expectation: write only D0
    add_write_request(0x01, 0b1010101101110111)
    print_red("\nWrite same upper 8-bit of data.")
    print_red("Expectation: write only D0")
    handle_write_request()

    # Write same lower 8-bit of data.
    # Expectation: write only D1
    add_write_request(0x01, 0b0000101001110111)
    print_red("\nWrite same lower 8-bit of data.")
    print_red("Expectation: write only D1")
    handle_write_request()

    # Write different upper 8-bit of data and lower 8-bit of data.
    # Expectation: write all blocks
    add_write_request(0x01, 0b0101000001110111)
    print_red("\nWrite different upper 8-bit of data and lower 8-bit of data.")
    print_red("Expectation: write all blocks")
    handle_write_request()


    print_red("\nStart: Write to address 0x00 0x02 0x03.")
    add_write_request(0x00, 0b1101001010101011)  # Write Request 2
    handle_write_request()
    add_write_request(0x02, 0b0011101010110101)  # Write Request 3
    handle_write_request()
    add_write_request(0x03, 0b1110001100111010)  # Write Request 4
    handle_write_request()
    print_red("\nEnd: Write to address 0x00 0x02 0x03.")

    print_red("\n❗ Simulating failure of Disk 0...")
    disk_status[0] = 0
    reset_disk(0)

    add_read_request(0x03)

    print_red("Try to read after failure of Disk 0")
    handle_read_request()

    print_red("Disk state after recovery from failure of Disk 0")
    print_disk_state()



    add_write_request(0x06, 0b1100101101010000)
    add_write_request(0x07, 0b1101001110101011)
    add_write_request(0x05, 0b0011101010111001)
    add_write_request(0x04, 0b1101001100111010)
    print_red("\n📥 Overflow write buffer")
    add_write_request(0x05, 0b1101001100111010)

    print("\n🛠️ Processing Write Requests...")
    while write_buffer_count > 0:
        handle_write_request()

    print_red("\n❗ Simulating failure of Disk 1...")
    disk_status[1] = 0
    reset_disk(1)

    add_read_request(0x03)

    print_red("Try to read after failure of Disk 1")
    handle_read_request()

    print_red("Disk state after recovery from failure of Disk 1")
    print_disk_state()

    print_red("\n❗ Simulating failure of Disk 2...")
    disk_status[2] = 0
    reset_disk(2)

    add_read_request(0x03)

    print_red("Try to read after failure of Disk 2")
    handle_read_request()

    print_red("Disk state after recovery from failure of Disk 2")
    print_disk_state()


    add_read_request(0x03)
    add_read_request(0x03)
    add_read_request(0x03)
    add_read_request(0x03)
    print_red("\n📥 Overflow read buffer")
    add_read_request(0x03)

    handle_read_request()

    print_red("\n📥 Check if Read Buffer Count=3")
    print_read_buffer()

    handle_read_request()
    handle_read_request()
    handle_read_request()

    print_red("\n💥 Simulation of SBE on D0 or D1")
    simulate_single_bit_error()

    print_red("\ndisk state after simulation of SBE on D0 or D1")
    print_disk_state()

    add_read_request(0x03)

    print_red("\nTry to read from 0x03 after simulation of SBE on D0 or D1")
    handle_read_request()

    print_red("\nDisk state after Hamming fix on 0x03. All the other stripes should remain unchanged(still corrupted)")
    print_disk_state()

    print_red("\nRead 0x01 to 0x07 in order to see if the will be fixed correctly")
    add_read_request(0x00)
    add_read_request(0x01)
    add_read_request(0x02)
    add_read_request(0x04)
    handle_read_request()
    handle_read_request()
    handle_read_request()
    handle_read_request()

    add_read_request(0x05)
    add_read_request(0x06)
    add_read_request(0x07)
    handle_read_request()
    handle_read_request()
    handle_read_request()

    print_red("\nNow Disk state should be fixed correctly")
    print_disk_state()

    print_red("\n💥💥 Simulation of SBE on D0 or D1")
    simulate_single_bit_error_D0_D1()

    print_red("\ndisk state after simulation of SBE on D0 or D1")
    print_disk_state()

    add_read_request(0x03)

    print_red("\nTry to read from 0x03 after simulation of SBE on D0 or D1")
    handle_read_request()

    print_red("\nDisk state after Hamming fix on 0x03. All the other stripes should remain unchanged(still corrupted)")
    print_disk_state()

    print_red("\nRead 0x01 to 0x07 in order to see if the will be fixed correctly")
    add_read_request(0x00)
    add_read_request(0x01)
    add_read_request(0x02)
    add_read_request(0x04)
    handle_read_request()
    handle_read_request()
    handle_read_request()
    handle_read_request()

    add_read_request(0x05)
    add_read_request(0x06)
    add_read_request(0x07)
    handle_read_request()
    handle_read_request()
    handle_read_request()

    print_red("\nNow Disk state should be fixed correctly")
    print_disk_state()
"""
"""
if __name__ == "__main__":
    original_stdout = sys.stdout
    write_sys_is_ready = 1  #
    read_sys_is_ready = 1  #



    with open("OUTPUT_simulate_mixed_10_write_distribution.txt", "w", encoding="utf-8") as file:
        sys.stdout = file  
        reset_write_counters()
        print("\n🔄 Initial RAID 5 System State:")
        print_disk_state()
        print_write_counters()

        num_requests = 10
        simulate_mixed_write_distribution(num_requests)

        print_disk_state()
        print_write_counters()

    sys.stdout = original_stdout

    print("✅ OUTPUT_simulate_mixed_10_write_distribution saved")


    with open("OUTPUT_simulate_mixed_100_write_distribution.txt", "w", encoding="utf-8") as file:
        sys.stdout = file  # 
        reset_write_counters()
        print("\n🔄 Initial RAID 5 System State:")
        print_disk_state()
        print_write_counters()

        num_requests = 100  # 
        simulate_mixed_write_distribution(num_requests)

        print_disk_state()
        print_write_counters()

    sys.stdout = original_stdout

    print("✅ OUTPUT_simulate_mixed_100_write_distribution saved")


    with open("OUTPUT_simulate_mixed_1000_write_distribution.txt", "w", encoding="utf-8") as file:
        sys.stdout = file  
        reset_write_counters()
        print("\n🔄 Initial RAID 5 System State:")
        print_disk_state()
        print_write_counters()

        num_requests = 1000  
        simulate_mixed_write_distribution(num_requests)

        print_disk_state()
        print_write_counters()

    sys.stdout = original_stdout

    print("✅ OUTPUT_simulate_mixed_1000_write_distribution saved")


    with open("OUTPUT_simulate_mixed_10000_write_distribution.txt", "w", encoding="utf-8") as file:
        sys.stdout = file  
        reset_write_counters()
        print("\n🔄 Initial RAID 5 System State:")
        print_disk_state()
        print_write_counters()

        num_requests = 10000 
        simulate_mixed_write_distribution(num_requests)

        print_disk_state()
        print_write_counters()

    sys.stdout = original_stdout

    print("✅ OUTPUT_simulate_mixed_10000_write_distribution saved")


    with open("OUTPUT_simulate_mixed_100000_write_distribution.txt", "w", encoding="utf-8") as file:
        sys.stdout = file 
        reset_write_counters()
        print("\n🔄 Initial RAID 5 System State:")
        print_disk_state()
        print_write_counters()

        num_requests = 100000  
        simulate_mixed_write_distribution(num_requests)

        print_disk_state()
        print_write_counters()

    sys.stdout = original_stdout

    print("✅ OUTPUT_simulate_mixed_100000_write_distribution saved")





"""
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import Patch

simulation_sizes = [10, 100, 1000, 10000, 100000]
disk_writes_round_robin = {
    "Disk 0": [10, 99, 967, 9550, 95602],
    "Disk 1": [10, 93, 910, 9207, 91473],
    "Disk 2": [7, 83, 868, 8667, 87139],
}
disk_writes_fixed_parity = {
    "Disk 0": [10, 90, 881, 8679, 87045],
    "Disk 1": [10, 85, 864, 8758, 87280],
    "Disk 2": [20, 200, 2000, 20000, 200000],
}

disk_colors = {
    "Disk 0": "#1f77b4",
    "Disk 1": "#ff7f0e",
    "Disk 2": "#2ca02c"
}

bar_width = 0.15
x = np.arange(len(simulation_sizes))

fig, ax = plt.subplots(figsize=(14, 8))

for i, disk in enumerate(disk_writes_round_robin.keys()):
    ax.bar(
        x + i * (bar_width * 2) - bar_width,
        disk_writes_round_robin[disk],
        bar_width,
        color=disk_colors[disk],
        edgecolor='black',
        linewidth=0.8,
        label=f"{disk} (Round Robin)" if i == 0 else None
    )
    ax.bar(
        x + i * (bar_width * 2),
        disk_writes_fixed_parity[disk],
        bar_width,
        color=disk_colors[disk],
        hatch='//',
        edgecolor='black',
        linewidth=0.8,
        label=f"{disk} (Fixed Parity)" if i == 0 else None
    )

xtick_labels = [f"$10^{int(np.log10(size))}$" for size in simulation_sizes]
ax.set_xticks(x + bar_width)
ax.set_xticklabels(xtick_labels, fontsize=11)

ax.yaxis.grid(True, which='both', linestyle='--', color='gray', alpha=0.5)

ax.set_title(
    "Comparison of Write Distribution Between Round Robin and Fixed Parity in RAID-5",
    fontsize=14,
    fontweight='bold'
)
ax.set_xlabel("Simulation Size", fontsize=12)
ax.set_ylabel("Number of Writes (Log Scale)", fontsize=12)
ax.set_yscale('log')

legend_patches = [
    Patch(facecolor='#1f77b4', edgecolor='black', linewidth=0.8, label='Disk 0 (Round Robin)'),
    Patch(facecolor='#1f77b4', edgecolor='black', hatch='//', linewidth=0.8, label='Disk 0 (Fixed Parity)'),
    Patch(facecolor='#ff7f0e', edgecolor='black', linewidth=0.8, label='Disk 1 (Round Robin)'),
    Patch(facecolor='#ff7f0e', edgecolor='black', hatch='//', linewidth=0.8, label='Disk 1 (Fixed Parity)'),
    Patch(facecolor='#2ca02c', edgecolor='black', linewidth=0.8, label='Disk 2 (Round Robin)'),
    Patch(facecolor='#2ca02c', edgecolor='black', hatch='//', linewidth=0.8, label='Disk 2 (Fixed Parity)')
]

ax.legend(handles=legend_patches, loc='upper left', fontsize=10)

fig.text(
    0.5, -0.1,
    ("In the traditional Fixed Parity RAID-5 system, the Parity disk experiences disproportionate wear because "
     "every data update requires a corresponding Parity block update. In contrast, the Round Robin distribution "
     "balances the writes across all disks, reducing wear on any single disk and extending overall system longevity."),
    wrap=True, horizontalalignment='center', fontsize=10
)

plt.tight_layout()
plt.show()


import matplotlib.pyplot as plt
import numpy as np

simulation_sizes = [10, 100, 1000, 10000, 100000]
disk_writes_round_robin = {
    "Disk 0": [10, 99, 967, 9550, 95602],
    "Disk 1": [10, 93, 910, 9207, 91473],
    "Disk 2": [7, 83, 868, 8667, 87139],
}
disk_writes_fixed_parity = {
    "Disk 0": [10, 90, 881, 8679, 87045],
    "Disk 1": [10, 85, 864, 8758, 87280],
    "Disk 2": [20, 200, 2000, 20000, 200000],
}

def calculate_wear_leveling(disk_writes):
    wear_levels = []
    for i in range(len(simulation_sizes)):
        writes = [disk_writes["Disk 0"][i], disk_writes["Disk 1"][i], disk_writes["Disk 2"][i]]
        mean = np.mean(writes)
        std_dev = np.std(writes)
        wear_level = (std_dev / mean) * 100
        wear_levels.append(wear_level)
    return wear_levels

wear_round_robin = calculate_wear_leveling(disk_writes_round_robin)
wear_fixed_parity = calculate_wear_leveling(disk_writes_fixed_parity)

x = np.arange(len(simulation_sizes))
bar_width = 0.35

fig, ax = plt.subplots(figsize=(14, 8))

ax.bar(
    x - bar_width / 2,
    wear_round_robin,
    bar_width,
    color='#1f77b4',
    edgecolor='black',
    label='Round Robin'
)
ax.bar(
    x + bar_width / 2,
    wear_fixed_parity,
    bar_width,
    color='#ff7f0e',
    edgecolor='black',
    label='Fixed Parity'
)

xtick_labels = [f"$10^{int(np.log10(size))}$" for size in simulation_sizes]
ax.set_xticks(x)
ax.set_xticklabels(xtick_labels, fontsize=11)
ax.set_title(
    "Wear Leveling Comparison Between Round Robin and Fixed Parity in RAID-5",
    fontsize=14,
    fontweight='bold'
)
ax.set_xlabel("Simulation Size", fontsize=12)
ax.set_ylabel("Wear Leveling (Standard Deviation %)", fontsize=12)

ax.legend(loc='upper left', fontsize=10)

ax.grid(True, which='both', linestyle='--', linewidth=0.5, alpha=0.7)

fig.text(
    0.5, -0.1,
    ("Wear leveling measures the distribution of writes across disks. Lower percentage indicates more balanced writes, "
     "while higher percentage indicates uneven write distribution. Round Robin aims to balance writes more effectively."),
    wrap=True, horizontalalignment='center', fontsize=10
)

plt.tight_layout()
plt.show()




import matplotlib.pyplot as plt
import numpy as np

simulation_sizes = [10, 100, 1000, 10000, 100000]

reads_fixed_parity = [30, 300, 3000, 30000, 300000]

reads_hamming_ecc = [20, 200, 2000, 20000, 200000]

bar_width = 0.35
x = np.arange(len(simulation_sizes))

fig, ax = plt.subplots(figsize=(14, 8))

ax.bar(
    x - bar_width / 2,
    reads_fixed_parity,
    bar_width,
    color='#1f77b4',
    edgecolor='black',
    label='RAID 5 without Hamming ECC'
)
ax.bar(
    x + bar_width / 2,
    reads_hamming_ecc,
    bar_width,
    color='#ff7f0e',
    edgecolor='black',
    label='RAID 5 with Hamming ECC'
)

ax.set_title(
    "Comparison of Read Operations Between RAID 5 with and without Hamming ECC",
    fontsize=14,
    fontweight='bold'
)
ax.set_xlabel("Simulation Size", fontsize=12)
ax.set_ylabel("Number of Read Operations (Log Scale)", fontsize=12)
ax.set_yscale('log')

xtick_labels = [f"$10^{int(np.log10(size))}$" for size in simulation_sizes]
ax.set_xticks(x)
ax.set_xticklabels(xtick_labels, fontsize=11)

ax.legend(loc='upper left', fontsize=10)

fig.text(
    0.5, -0.1,
    ("In the traditional RAID 5 (Fixed Parity) system, each read operation requires reading all three blocks (D0, D1, and Parity) "
     "to detect and correct errors. In contrast, RAID 5 with Hamming ECC only requires reading D0 and D1 for most operations, "
     "reducing the overall number of read operations significantly."),
    wrap=True, horizontalalignment='center', fontsize=10
)

plt.tight_layout()
plt.show()


