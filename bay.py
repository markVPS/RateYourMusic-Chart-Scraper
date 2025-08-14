import os

# List all .tsv files in the current directory
tsv_files = [f for f in os.listdir('.') if f.endswith('.tsv')]

# Display the list with numbers
print("Select a TSV file to process:\n")
for idx, fname in enumerate(tsv_files, 1):
    print(f"{idx}. {fname}")

# Prompt the user to choose a file by number
while True:
    try:
        choice = int(input("\nEnter the number of the file: "))
        if 1 <= choice <= len(tsv_files):
            file = tsv_files[choice - 1]
            break
        else:
            print("Please enter a valid number from the list.")
    except ValueError:
        print("Invalid input. Please enter a number.")

print(f"\nSelected file: {file}")


# Check if file exists
if not os.path.isfile(file):
    print(f"Error: File '{file}' not found.")
    exit(1)

# Initialize variables
total_ratings = 0
total_sum = 0.0
min_value = float('inf')
temp_file = "temp_director_list.tsv"

# Read through the file line by line
with open(file, 'r') as f, open(temp_file, 'w') as temp_f:
    # Read and write the first line (header) without any modification
    header_line = f.readline()
    temp_f.write(header_line)
    
    for line in f:
        # Skip empty lines or lines starting with a question mark
        if not line.strip() or line.startswith('?'):
            continue
        
        # Split the line into columns (assuming tab-separated)
        columns = line.split('\t')
        
        # Ensure we have three columns: name, ratings, and average
        if len(columns) < 3:
            continue
        
        # Get director name (may contain spaces), ratings, and average
        name = '\t'.join(columns[:-2]).strip()  # Join all but last two columns for the name
        ratings = columns[-2].strip()  # Ratings are the second-to-last column
        average = columns[-1].strip()  # Average is the last column

        # Skip if any of the fields are missing or invalid
        if not ratings or not average:
            continue
        
        try:
            ratings = int(ratings)  # Ratings are integers
            average = float(average)  # Average is a float
        except ValueError:
            print(f"Error: Invalid number format in line: '{ratings}', '{average}'")
            continue
        
        # Update totals
        total_ratings += ratings
        total_sum += average
        
        # Update minimum value if needed
        if average < min_value:
            min_value = average
        
        # Store original lines
        temp_f.write(f"{name}\t{ratings}\t{average}\n")

# Calculate overall average (M) and constant weight (C)
entry_count = sum(1 for line in open(file)) - 1  # Subtract 1 for the header line
M = total_sum / entry_count
C = total_ratings / entry_count

# Rewrite file with Bayesian average appended as the fourth column
with open(temp_file, 'r') as temp_f, open(file, 'w') as f:
    # Copy header line to output file
    f.write(header_line)
    
    for line in temp_f:
        # Skip the header line (it's already written)
        if line == header_line:
            continue
        
        # Split the line into columns (name, ratings, average)
        columns = line.split('\t')
        
        name = columns[0].strip()
        ratings = columns[1].strip()
        average = columns[2].strip()

        try:
            ratings = int(ratings)
            average = float(average)
        except ValueError:
            continue
        
        # Calculate Bayesian average
        bayesian_avg = (C * M + ratings * average) / (C + ratings)
        
        # Popularity boost
        if ratings > C:
            bayesian_avg += 0.00000001 * (ratings - C)  # Boost the average if ratings are above C

        # Write the updated line to the file
        f.write(f"{name}\t{ratings}\t{average}\t{bayesian_avg:.5f}\n")

# Clean up temporary file
os.remove(temp_file)

print(f"Bayesian averages appended to {file}")
