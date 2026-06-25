with open('analyze_output.txt', 'r') as f:
    lines = f.readlines()

print(f"Total lines: {len(lines)}")
for line in lines:
    if 'error' in line.lower() or 'warning' in line.lower() or 'octopainter' in line.lower() or 'authprovider' in line.lower():
        print(line.strip())
