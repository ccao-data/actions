import sys
import yaml

def main(hooks_list):
    hooks = hooks_list.split(',')  # Split the comma-separated list into Python list
    config_path = '.pre-commit-config.yaml'

    with open(config_path, 'r') as file:
        data = yaml.safe_load(file)  # Load the existing YAML file

    # Filter out hooks not specified in the input
    for repo in data['repos']:
        repo['hooks'] = [hook for hook in repo['hooks'] if hook['id'] in hooks]

    # Write the modified config back to the file
    with open(config_path, 'w') as file:
        yaml.safe_dump(data, file)

if __name__ == '__main__':
    hooks_input = sys.argv[1]  # Expect the first argument to be the comma-separated hooks list
    main(hooks_input)
