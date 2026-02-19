#!/usr/bin/bash

# Function to handle Ctrl+C (SIGINT)
cleanup() {
	    echo -e "\n\nScript interrupted! Saving current progress..."
	        
# Archive the current project directory
archive_name="attendance_tracker_${input}_archive.zip"
zip -r "$archive_name" . > /dev/null 2>&1
echo "Current project archived as $archive_name"

# Go back and delete incomplete directory
cd ..
rm -rf "attendance_tracker_${input}"
echo "Incomplete project directory removed. Exiting."
exit 1
	}

# Set trap for SIGINT (Ctrl+C)
trap cleanup SIGINT

# Ask for tracker name
read -p "Enter tracker name: " input

# Check if user entered something
if [ -z "$input" ]; then
	echo "Error: Please enter the tracker name!"
	exit 1
fi

#Environment Health Check

echo -e "\nPerforming environment health check"
if command -v python3 > /dev/null 2>&1; then
version=$(python3 --version)
echo "Python3 found: $version"
else
echo "Warning: Python3 is not installed! The tracker may not run properly."
fi

#Create parent directory
mkdir -p "attendance_tracker_${input}"
# Check if directory creation failed
if [ $? -ne 0 ]; then
    echo "Error: Could not create project directory. Check permissions."
    exit 1
fi
cd "attendance_tracker_${input}" || exit

#Validate and create subdirectories
required_dirs=("Helpers" "reports")
for dir in "${required_dirs[@]}"; do
if [ ! -d "$dir" ]; then
mkdir -p "$dir"
echo "Created missing directory: $dir"
fi
done

#Create main Python file if missing
if [ ! -f attendance_checker.py ]; then
touch attendance_checker.py
cat > attendance_checker.py << EOF
import csv
import json
import os
from datetime import datetime

def run_attendance_check():
    # 1. Load Config
    with open('Helpers/config.json', 'r') as f:
        config = json.load(f)
    
    # 2. Archive old reports.log if it exists
    if os.path.exists('reports/reports.log'):
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        os.rename('reports/reports.log', f'reports/reports_{timestamp}.log.archive')

    # 3. Process Data
    with open('Helpers/assets.csv', mode='r') as f, open('reports/reports.log', 'w') as log:
        reader = csv.DictReader(f)
        total_sessions = config['total_sessions']
        
        log.write(f"--- Attendance Report Run: {datetime.now()} ---\n")
        
        for row in reader:
            name = row['Names']
            email = row['Email']
            attended = int(row['Attendance Count'])
            
            # Simple Math: (Attended / Total) * 100
            attendance_pct = (attended / total_sessions) * 100
            
            message = ""
            if attendance_pct < config['thresholds']['failure']:
                message = f"URGENT: {name}, your attendance is {attendance_pct:.1f}%. You will fail this class."
            elif attendance_pct < config['thresholds']['warning']:
                message = f"WARNING: {name}, your attendance is {attendance_pct:.1f}%. Please be careful."
            
            if message:
                if config['run_mode'] == "live":
                    log.write(f"[{datetime.now()}] ALERT SENT TO {email}: {message}\n")
                    print(f"Logged alert for {name}")
                else:
                    print(f"[DRY RUN] Email to {email}: {message}")

if __name__ == "__main__":
    run_attendance_check() 
EOF
    echo "Created main Python file: attendance_checker.py"
fi

# Make Python executable
chmod +x attendance_checker.py

#Create assets.csv if missing
if [ ! -f Helpers/assets.csv ]; then
    cat > Helpers/assets.csv << EOF
Email,Names,Attendance Count,Absence Count
alice@example.com,Alice Johnson,14,1
bob@example.com,Bob Smith,7,8
charlie@example.com,Charlie Davis,4,11
diana@example.com,Diana Prince,15,0

EOF
    echo "Created Helpers/assets.csv"
fi

#Create config.json if missing
if [ ! -f Helpers/config.json ]; then
	    cat > Helpers/config.json <<EOL
{
    "thresholds": {
        "warning": 75,
        "failure": 50
    },
    "run_mode": "live",
    "total_sessions": 15
}
EOL
    echo "Created Helpers/config.json"
fi

#Create reports.log if missing
if [ ! -f reports/reports.log ]; then
	    cat > reports/reports.log <<EOL
--- Attendance Report Run: $(date +"%Y-%m-%d %H:%M:%S") ---
[ALERT EXAMPLE] ALERT SENT TO bob@example.com: URGENT: Bob Smith, your attendance is 46.7%. You will fail this class.
[ALERT EXAMPLE] ALERT SENT TO charlie@example.com: URGENT: Charlie Davis, your attendance is 26.7%. You will fail this class.

EOL
    echo "Created reports/reports.log"
fi

#Dynamic Configuration Update
echo -e "\nDo you want to update attendance thresholds? (yes/no)"
read update_config

# Default to "no" if nothing is typed
update_config=${update_config:-no}

if [[ "$update_config" == "yes" ]]; then
	   read -p "Enter Warning threshold (default 75): " warning
	   read -p "Enter Failure threshold (default 50): " failure

# Use defaults if user leaves blank
warning=${warning:-75}
failure=${failure:-50}
#Check if warning is numeric
if ! [[ "$warning" =~ ^[0-9]+$ ]]; then
    echo "Error: Warning threshold must be a number."
    exit 1
fi

#Check if  failure is numeric
if ! [[ "$failure" =~ ^[0-9]+$ ]]; then
    echo "Error: Failure threshold must be a number."
    exit 1
fi
# Update config.json using sed
sed -i "s/\"warning\": [0-9]\+/\"warning\": $warning/" Helpers/config.json
sed -i "s/\"failure\": [0-9]\+/\"failure\": $failure/" Helpers/config.json

echo "Config updated: Warning=$warning%, Failure=$failure%"
else
echo "Thresholds not changed.Make sure to type as instructed on the tab"
fi

#project structure
echo -e "\nProject setup complete!"
echo "Path: $(pwd)"
if command -v tree > /dev/null 2>&1; then
    tree -F
else
    echo "Tree command not found. Showing basic structure:"
    ls -R
fi
