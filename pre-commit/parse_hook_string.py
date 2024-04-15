import sys
import yaml

def main(hooks_list):
    hooks = hooks_list.split(',')
    print("Enabled hooks:", hooks)

    config_path = '.pre-commit-config.yaml'

    try:
        with open(config_path, 'r') as file:
            data = yaml.safe_load(file)
    except FileNotFoundError:
        print(f"Error: File not found: {config_path}")
        sys.exit(1)

    print("Original configuration:", data)  # Debugging statement

    for repo in data['repos']:
        original_hooks = repo['hooks']
        repo['hooks'] = [hook for hook in repo['hooks'] if hook['id'] in hooks]
        print(f"Repo: {repo['repo']} | Original Hooks: {original_hooks} | Filtered Hooks: {repo['hooks']}")

    with open(config_path, 'w') as file:
        yaml.safe_dump(data, file)

if __name__ == '__main__':
    hooks_input = sys.argv[1]
    main(hooks_input)
