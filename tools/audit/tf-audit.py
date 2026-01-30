import os
import re
import sys

# tf-audit.py - Auditoria de Variáveis e Redundâncias Terraform
# Autor: Antigravity (Anttaskjr AI)

def find_unused_vars(root_dir):
    print(f"--- Analisando variáveis em: {root_dir} ---")
    
    # 1. Mapear todas as variáveis declaradas
    declared_vars = set()
    for root, dirs, files in os.walk(root_dir):
        for file in files:
            if file.endswith("variables.tf"):
                with open(os.path.join(root, file), 'r') as f:
                    content = f.read()
                    matches = re.findall(r'variable\s+"(.*?)"', content)
                    declared_vars.update(matches)
    
    # 2. Mapear todas as variáveis utilizadas
    used_vars = set()
    for root, dirs, files in os.walk(root_dir):
        for file in files:
            if file.endswith(".tf") and not file.endswith("variables.tf"):
                with open(os.path.join(root, file), 'r') as f:
                    content = f.read()
                    # Busca por var.nome_da_variavel
                    matches = re.findall(r'var\.(.*?)[^a-zA-Z0-9_]', content + " ")
                    used_vars.update(matches)
    
    # 3. Comparar
    unused = declared_vars - used_vars
    
    if unused:
        print(f"\033[91mVariáveis declaradas mas não utilizadas (pode haver falsos positivos em módulos):\033[0m")
        for var in sorted(unused):
            print(f" - {var}")
    else:
        print("\033[92mNenhuma variável não utilizada detectada!\033[0m")

def check_redundancies(root_dir):
    print(f"\n--- Analisando redundâncias em Security Lists ---")
    # Busca por blocos de security rules repetidos (heurística simples)
    rules_seen = {}
    for root, dirs, files in os.walk(root_dir):
        for file in files:
            if file.endswith(".tf"):
                with open(os.path.join(root, file), 'r') as f:
                    content = f.read()
                    # Analisando blocos ingress_security_rules simples
                    blocks = re.findall(r'ingress_security_rules\s+\{(.*?)\}', content, re.DOTALL)
                    for block in blocks:
                        clean_block = "".join(block.split()) # Remove todos os espaços
                        if clean_block in rules_seen:
                            print(f"\033[93mAlerta: Regra de Ingress possivelmente duplicada detectada em {file}\033[0m")
                        rules_seen[clean_block] = file

if __name__ == "__main__":
    base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../"))
    find_unused_vars(base_path)
    check_redundancies(base_path)
