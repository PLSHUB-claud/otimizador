# 🚀 Configuração Rápida de Servidor SSH + Tailscale

Script 100% automático para transformar este PC Windows em um servidor de bots acessível remotamente.

---

## ⚡ Passo a Passo (Para quem vai rodar no PC)

### Opção 1: Via Linha de Comando (Recomendado)

1. Pressione a tecla **Windows** e digite `PowerShell`.
2. Clique com o botão direito em **PowerShell** e escolha **Executar como Administrador**.
3. Copie o bloco abaixo, cole na janela e aperte **Enter**:

```powershell
git clone https://github.com/PLSHUB-claud/windows-ssh-setup.git; cd windows-ssh-setup; Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force; .\setup.ps1
```

---

### Opção 2: Manual (Dois cliques)

1. Faça o download ou clone este repositório.
2. Abra a pasta baixada.
3. Clique com o botão direito no arquivo **`run.bat`** e escolha **Executar como Administrador** (ou apenas dê dois cliques e confirme o aviso "Sim").

---

### 🔑 Durante / Final da Execução:

1. **Tailscale:** Se abrir o navegador pedindo login do Tailscale, faça login com sua conta (Google, Microsoft, GitHub, etc.) para autorizar a máquina.
2. **Ao terminar:** O script vai mostrar na tela algo como:
   ```text
   Usuario:      nome_do_usuario
   IP Tailscale: 100.x.y.z
   ```
3. Basta copiar esses dois dados e mandar para quem vai gerenciar o servidor!
