# Docker Desktop no runner `windows-2025` do GitHub Actions

Exploração feita em 22/10/2026 para decidir onde rodar os testes e2e do
WinPlaybook. Repositório descartável:
[LeonardoSextare/docker-desktop-gha-probe](https://github.com/LeonardoSextare/docker-desktop-gha-probe).
Todos os links de run apontam para os logs completos.

Convenção deste relatório: **Medido** vem de um log ou artifact citado;
**Suposição** é interpretação ou conhecimento prévio ainda não verificado.

## 1. Veredito

**Sim.** No `windows-2025` gratuito, o Docker Desktop 4.96.3 com backend WSL2
instalou sem pedir reboot e subiu o motor Linux em **4 de 4** execuções (hosts
AMD e Intel). O WinPlaybook (`Invoke-WinPlaybook`) rodou playbooks nos dois
PowerShells. A condição é parar antes o motor Docker Windows que vem
pré-instalado no runner. O cenário não tem suporte oficial do Docker (Windows
Server) e depende de virtualização aninhada.

## 2. Inventário do runner

Fonte: [run 39823005104](https://github.com/LeonardoSextare/docker-desktop-gha-probe/actions/runs/39823005104)
(artifact `inventory-39823005104`), mais o passo "Host summary" de cada run
posterior. **Medido.**

| Item | Valor |
|---|---|
| Sistema | Windows Server 2025 Datacenter, build 10.0.26100 (`.33438` a `.33650`, conforme a imagem) |
| Imagem do runner (`ImageOS`) | `win25-vs2026`; versões vistas no mesmo dia: `20261007.264.1`, `20261018.275.1`, `20261021.278.1` |
| CPU | 2 núcleos / 4 lógicos. Modelos vistos: AMD EPYC 9V74, AMD EPYC 7763, Intel Xeon Platinum 8573C, Intel Xeon Platinum 8370C |
| Memória | 16 GB (13,7 GB livres no início do job) |
| Disco livre | C: 31,7 GB de 150 GB; D: 147 GB de 150 GB |
| Hypervisor | `HypervisorPresent = True`, `hypervisorlaunchtype Auto`; `systeminfo`: "A hypervisor has been detected" |
| `VirtualizationFirmwareEnabled` | `True` (SLAT e VMMonitorModeExtensions aparecem `False`, ver nota) |
| Recursos opcionais | `Microsoft-Windows-Subsystem-Linux`, `VirtualMachinePlatform`, `Microsoft-Hyper-V`, `Containers`: todos **Enabled** |
| KB5127648 | **Não instalado** em nenhum host. Hotfixes vistos: KB5127690, KB5126646, KB5126645 (13/10/2026) ou KB5126052, KB5122871, KB5122870 (05/09/2026), conforme a imagem |
| WSL | 3.0.3.0 (kernel 6.18.54.1) ou 3.0.1.0 (kernel 6.18.40.1), conforme a imagem; versão padrão 2; nenhuma distro instalada |
| Docker pré-instalado | `C:\Windows\system32\docker.exe` 29.7.2 + serviço `docker` (Docker Engine Community, `OSType: windows`, pipe `docker_engine`). Sem Docker Desktop |
| Contextos Docker | só `default` → `npipe:////./pipe/docker_engine` |
| PowerShell | 7.6.6 ou 7.6.7, e 5.1.26100.x |
| Pester | 5.9.0 e 3.4.0, visíveis nos dois shells. **Sem Pester 6** |
| Usuário do job | `runneradmin`, membro de Administrators, nível de integridade High |

Nota (**Suposição**): com um hypervisor ativo, o WMI costuma mostrar SLAT e
VMMonitorModeExtensions como `False` mesmo quando a virtualização aninhada
funciona. Esses dois valores não serviram como evidência; o teste que decidiu
foi o WSL2 subir.

## 3. Tempos

### WSL2 com `Vampire/setup-wsl` (pergunta 2)

| Run | Host | Imagem | Cache | `setup-wsl` | Job |
|---|---|---|---|---|---|
| [39824013407](https://github.com/LeonardoSextare/docker-desktop-gha-probe/actions/runs/39824013407) | Intel Xeon 8573C | 20261021.278.1 | não | 9min53s | 10min14s |
| [39824027230](https://github.com/LeonardoSextare/docker-desktop-gha-probe/actions/runs/39824027230) | AMD EPYC 7763 | 20261007.264.1 | não | 15min37s | 15min55s |
| [39824041150](https://github.com/LeonardoSextare/docker-desktop-gha-probe/actions/runs/39824041150) | AMD EPYC 9V74 | 20261021.278.1 | não | 13min41s | 14min21s |
| [39826754127](https://github.com/LeonardoSextare/docker-desktop-gha-probe/actions/runs/39826754127) | Intel Xeon 8370C | 20261021.278.1 | **sim** | **48 s** | **1min45s** |

Sem cache, quase todo o tempo é o download da distro: 387 MB em 8min37s,
15min01s e 12min56s. Isso dá cerca de 0,4 a 0,75 MB/s, sem progresso no log.
Instalar a distro levou de 21 a 31 s e o primeiro boot de 9 a 27 s. Com cache,
o restore foi a 108 MB/s (`Cache hit for: 2:distributionDirectory_Ubuntu_24.4.5`,
369 MB). **Medido.**

### Docker Desktop (perguntas 3 e 4)

| Run | Host | Imagem | Versão | Download | Instalação | Motor Linux pronto | Job |
|---|---|---|---|---|---|---|---|
| [39827062687](https://github.com/LeonardoSextare/docker-desktop-gha-probe/actions/runs/39827062687) | AMD EPYC 7763 | 20261021.278.1 | 4.96.2 | 2,8 s | 76,1 s | **falhou** (ver seção 5) | 11min48s |
| [39828911884](https://github.com/LeonardoSextare/docker-desktop-gha-probe/actions/runs/39828911884) | AMD EPYC 9V74 | 20261007.264.1 | 4.96.3 | 2,9 s | 61,5 s | 52,4 s | 2min52s |
| [39829468679](https://github.com/LeonardoSextare/docker-desktop-gha-probe/actions/runs/39829468679) | AMD EPYC 9V74 | 20261018.275.1 | 4.96.3 | 2,3 s | 53,0 s | 43,6 s | 2min43s |
| [39829481395](https://github.com/LeonardoSextare/docker-desktop-gha-probe/actions/runs/39829481395) | AMD EPYC 7763 | 20261007.264.1 | 4.96.3 | 2,5 s | 61,7 s | 54,6 s | 2min59s |
| [39829493903](https://github.com/LeonardoSextare/docker-desktop-gha-probe/actions/runs/39829493903) | Intel Xeon 8573C | 20261018.275.1 | 4.96.3 | 3,4 s | 85,9 s | 84,3 s | 3min56s |

O instalador tem 612 MB (4.96.3) ou 621 MB (4.96.2). O método foi o instalador
oficial
(`https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe`)
com `install --quiet --accept-license --backend=wsl-2`, que sempre terminou com
exit code `0`. winget e chocolatey não foram testados, porque o instalador
oficial funcionou de primeira. "Motor pronto" vai do `Start-Process` do
`Docker Desktop.exe` até `docker info` responder `OSType=linux`. **Medido.**

Testes funcionais, em segundos, nas 4 execuções que funcionaram (ordem dos
runs da tabela acima). **Medido.**

| Teste | PowerShell 7 | Windows PowerShell 5.1* |
|---|---|---|
| `docker run --rm hello-world` | 2,8 / 4,4 / 3,0 / 2,8 | 1,2 / 1,5 / 1,2 / 1,0 |
| `--volume C:\temp\projeto:/work ... alpine ls -la` | 3,2 / 6,3 / 3,6 / 3,5 | 1,8 / 1,3 / 1,1 / 1,1 |
| `docker pull ghcr.io/leonardosextare/winplaybook:0` | 14,7 / 13,4 / 15,8 / 13,4 | 2,6 / 1,8 / 1,4 / 1,3 |
| `... winplaybook:0 ansible --version` | 5,3 / 5,1 / 4,3 / 7,6 | 3,1 / 2,0 / 2,2 / 2,0 |
| `alpine echo '{\"a\": \"b c\"}'` | 1,3 / 1,7 / 1,2 / 1,0 | 1,5 / 1,2 / 1,2 / 1,0 |

\* O 5.1 roda depois do 7, na mesma máquina, com as imagens já baixadas. Os
tempos do 5.1 não incluem download.

Resultados (**Medido**, iguais nas 4 execuções):
- A montagem de `C:\temp\projeto` mostra `arquivo.txt` em `/work`
  (`-rwxrwxrwx 1 root root 20 ... arquivo.txt`).
- `ansible --version`: `ansible [core 2.21.5]`, Python 3.14.8.
- O argumento com aspas chega **diferente** em cada shell:

  | Shell | O que o container recebeu |
  |---|---|
  | PowerShell 7.6 | `{\"a\": \"b c\"}` |
  | Windows PowerShell 5.1 | `{"a": "b c"}` |

### Prova de conceito com o WinPlaybook

O workflow `winplaybook-poc.yml` faz checkout do WinPlaybook no commit
`31c4691` (`feat: convert Windows paths in command arguments`), importa o módulo,
copia `tests/data/projects/hello` e roda `Invoke-WinPlaybook` com a imagem
publicada `ghcr.io/leonardosextare/winplaybook:0`. Um comando só passa se o exit
code for 0 **e** a saída tiver o texto esperado.

| Run | Host | Motor pronto | Job | Resultado |
|---|---|---|---|---|
| [39830318932](https://github.com/LeonardoSextare/docker-desktop-gha-probe/actions/runs/39830318932) | AMD EPYC 9V74 | 73,0 s | 3min58s | 7: 3/3 ok; 5.1: falhou no 1º comando (seção 5, erro 3) |
| [39831085266](https://github.com/LeonardoSextare/docker-desktop-gha-probe/actions/runs/39831085266) | AMD EPYC 7763 | 71,7 s | 3min20s | 7: 3/3 ok; 5.1: 3/3 ok |

Tempos do run 39831085266, em segundos. **Medido.**

| Comando | PowerShell 7.6.6 | Windows PowerShell 5.1 |
|---|---|---|
| `Invoke-WinPlaybook ansible-playbook site.yml` | 26,9 (com download da imagem) | 3,5 |
| `Invoke-WinPlaybook ansible-playbook .\site.yml` | 3,7 | 2,8 |
| `Invoke-WinPlaybook ansible localhost -m ansible.builtin.debug -a 'msg={{ greeting }}' -e '{"greeting": "hello world"}'` | 2,8 | 2,4 |

Saídas conferidas: `"msg": "hello from WinPlaybook"` e `"msg": "hello world"`
nos dois shells. Com o módulo, o JSON chega igual no 5.1 e no 7, ao contrário
do `docker` chamado direto (tabela anterior).

## 4. Estabilidade

| Experimento | Execuções | Sucesso | Falhas e causa |
|---|---|---|---|
| Inventário | 1 | 1 | — |
| WSL2 (`setup-wsl`) | 4 | 4 | — |
| Motor Windows pré-instalado com imagem Linux | 4 | 0 (esperado) | `no matching manifest for windows(10.0.26100)/amd64` |
| Docker Desktop, workflow original | 1 | 0 | conflito no pipe `docker_engine` (seção 5, erro 2) |
| Docker Desktop, com o serviço `docker` parado | 4 | **4** | — |
| Prova de conceito WinPlaybook | 2 | 1 | 1ª: erro do script de teste no 5.1 (seção 5, erro 3) |

Hosts das 4 execuções do Docker Desktop que funcionaram: 3 AMD (EPYC 9V74 e
7763) e 1 Intel (Xeon 8573C), em duas versões de imagem. A prova de conceito
corrigida rodou **só 1 vez**, abaixo do mínimo de 3 pedido.

## 5. Erros encontrados

### Erro 1: o Docker pré-instalado não roda imagem Linux

[Run 39824013407](https://github.com/LeonardoSextare/docker-desktop-gha-probe/actions/runs/39824013407),
igual nas outras 3:

```
OSType=windows
Unable to find image 'alpine:latest' locally
latest: Pulling from library/alpine
docker: no matching manifest for windows(10.0.26100)/amd64 in the manifest list entries
```

O motor que vem no runner é o Docker Engine nativo do Windows e só executa
containers Windows. Container não tem kernel próprio, então uma imagem Linux
precisa de um kernel Linux. Esse kernel é o que o Docker Desktop fornece, pela
VM do WSL2.

### Erro 2: Docker Desktop cai por conflito no pipe `docker_engine`

[Run 39827062687](https://github.com/LeonardoSextare/docker-desktop-gha-probe/actions/runs/39827062687),
artifact `docker-desktop-logs-39827062687`, arquivo `com.docker.backend.exe.log`:

```
[2026-10-22T17:58:23.629465200Z][com.docker.backend.exe] backend cancelling with error: starting services:
initializing Docker API Proxy: setting up docker api proxy listener: open \\.\pipe\docker_engine: Access is denied.
(listener: ALLOWED BUILTIN\Administrators (Flags:0x00, Mask:0x001F01FF), ALLOWED NT AUTHORITY\SYSTEM (Flags:0x00, Mask:0x001F01FF))
...
[2026-10-22T17:58:27.376559000Z][com.docker.backend.exe] backend crashed, dumping error to file and reporting to user: ...
```

No log do job, o loop esperou os 10 minutos do limite:

```
   11 s: failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine; ...
       open //./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified.
...
Engine ready check: OSType= failed to connect ... after 607.7 s
```

Causa (**Medido**): o Docker Desktop cria um proxy no pipe padrão
`\\.\pipe\docker_engine`, que o serviço `docker` pré-instalado já ocupa. O
backend aborta e abre uma janela de erro ("Quit / Reset to factory defaults")
que ninguém fecha. Correção: `Stop-Service docker` antes de iniciar o Docker
Desktop. Depois dela, o pipe sumiu (`docker_engine pipe exists: False`) e as
4 execuções seguintes funcionaram. O loop também passou a ler o log do backend
e falhar na hora ao ver `backend crashed`.

### Erro 3: Windows PowerShell 5.1 interrompe o módulo no primeiro aviso do Ansible

[Run 39830318932](https://github.com/LeonardoSextare/docker-desktop-gha-probe/actions/runs/39830318932),
passo "WinPlaybook (Windows PowerShell 5.1)":

```
docker : [WARNING]: No inventory was parsed, only implicit localhost is available
At D:\a\...\winplaybook\module\WinPlaybook\Private\Container\Invoke-AnsibleContainer.ps1:43 char:5
+     docker @dockerArguments
    + CategoryInfo          : NotSpecified: ([WARNING]: No i...st is available:String) [], RemoteException
    + FullyQualifiedErrorId : NativeCommandError
##[error]Process completed with exit code 1.
```

Causa (**Medido**, confirmado pelo run 39831085266):
- O GitHub Actions define `$ErrorActionPreference = 'Stop'` no escopo global de
  cada passo `shell: powershell`.
- O script de teste redireciona a saída com `2>&1`. No 5.1, com `Stop`, a
  primeira linha de stderr do `docker` (aqui um aviso do Ansible) vira um erro
  que interrompe o comando.
- `$ErrorActionPreference = 'Continue'` no topo do script não resolve, porque
  as funções do módulo leem o valor **global**. Com
  `$global:ErrorActionPreference = 'Continue'`, os 3 comandos passam.
- Mesmo assim, no 5.1 os avisos continuam aparecendo na saída formatados como
  erro (`NativeCommandError`), sem interromper.

**Suposição:** um usuário do 5.1 com `$ErrorActionPreference = 'Stop'` global
que redirecione a saída do `Invoke-WinPlaybook` cai no mesmo erro. Num console
interativo, sem redirecionamento, provavelmente não aparece. Nenhum dos dois
casos foi testado.

### Ajuste do próprio experimento (não é erro do ambiente)

O primeiro inventário saiu com as linhas do `Get-ComputerInfo` vazias: misturei
objetos de tipos diferentes numa mesma tabela. Corrigi com `Format-List` (commit
`78f54f1`); o `systeminfo` já trazia os mesmos dados.

## 6. Workflows que funcionaram

Versões fixadas por SHA de commit, conferidas na API do GitHub em 22/10/2026:

| Action | Tag | Commit |
|---|---|---|
| `actions/checkout` | v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| `actions/upload-artifact` | v7.0.2 | `cf430e030ddbb5b0abf93d22962f4752f3646cd9` |
| `Vampire/setup-wsl` (só no `wsl2.yml`) | v7.2.0 | `4c48163d9f981914dd8caa0fc335fe19cca5bff4` |

O SHA fixa o código exato; uma tag pode ser movida para outro commit. Os
scripts chamados pelos workflows estão no repositório, no commit `afb34c6`:
[`scripts/reboot-flags.ps1`](https://github.com/LeonardoSextare/docker-desktop-gha-probe/blob/afb34c610f4b0dc3803a8445bdc5a06bc64c1ce0/scripts/reboot-flags.ps1),
[`scripts/docker-tests.ps1`](https://github.com/LeonardoSextare/docker-desktop-gha-probe/blob/afb34c610f4b0dc3803a8445bdc5a06bc64c1ce0/scripts/docker-tests.ps1),
[`scripts/winplaybook-poc.ps1`](https://github.com/LeonardoSextare/docker-desktop-gha-probe/blob/afb34c610f4b0dc3803a8445bdc5a06bc64c1ce0/scripts/winplaybook-poc.ps1).

### `.github/workflows/docker-desktop.yml` (testes da pergunta 4, 4/4)

```yaml
name: docker-desktop

on:
  workflow_dispatch:

permissions:
  contents: read

env:
  INSTALLER_URL: https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe
  DOCKER_BIN: C:\Program Files\Docker\Docker\resources\bin

jobs:
  docker-desktop:
    runs-on: windows-2025
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1

      - name: Host summary
        shell: pwsh
        run: |
          $env:WSL_UTF8 = '1'
          "ImageVersion=$env:ImageVersion"
          (Get-CimInstance Win32_Processor).Name
          Get-HotFix | Format-Table HotFixID, InstalledOn -AutoSize | Out-String
          wsl --version
          "USERNAME=$env:USERNAME"
          whoami /groups | Select-String 'Administrators|Mandatory Label'

      - name: Download installer
        shell: pwsh
        run: |
          $stopwatch = [Diagnostics.Stopwatch]::StartNew()
          Invoke-WebRequest -Uri $env:INSTALLER_URL -OutFile "$env:RUNNER_TEMP\DockerDesktopInstaller.exe"
          $stopwatch.Stop()
          $file = Get-Item "$env:RUNNER_TEMP\DockerDesktopInstaller.exe"
          "Size: {0:N0} MB" -f ($file.Length / 1MB)
          "Version: $($file.VersionInfo.ProductVersion)"
          "Download time: {0:N1} s" -f $stopwatch.Elapsed.TotalSeconds

      - name: Reboot flags before install
        shell: pwsh
        run: ./scripts/reboot-flags.ps1

      - name: Install
        shell: pwsh
        run: |
          $stopwatch = [Diagnostics.Stopwatch]::StartNew()
          $process = Start-Process -FilePath "$env:RUNNER_TEMP\DockerDesktopInstaller.exe" -Wait -PassThru `
              -ArgumentList 'install', '--quiet', '--accept-license', '--backend=wsl-2'
          $stopwatch.Stop()
          "Installer exit code: $($process.ExitCode)   (3010 = restart required)"
          "Install time: {0:N1} s" -f $stopwatch.Elapsed.TotalSeconds
          net localgroup docker-users
          # The installer changes the machine PATH, but this job keeps the PATH it started with.
          Add-Content -Path $env:GITHUB_PATH -Value $env:DOCKER_BIN
          # Explicit exit: otherwise the step ends with the exit code of the last native command.
          if ($process.ExitCode -notin 0, 3010) { exit $process.ExitCode } else { exit 0 }

      - name: Reboot flags after install
        shell: pwsh
        run: ./scripts/reboot-flags.ps1

      # The preinstalled Windows engine owns \\.\pipe\docker_engine, which Docker Desktop
      # needs for its API proxy; with it running, the Docker Desktop backend crashes.
      - name: Stop the preinstalled Windows engine
        shell: pwsh
        run: |
          Stop-Service -Name docker
          Set-Service -Name docker -StartupType Disabled
          Get-Service -Name docker | Format-Table Name, Status, StartType -AutoSize | Out-String
          "docker_engine pipe exists: $(Test-Path '\\.\pipe\docker_engine')"

      - name: Start Docker Desktop and wait for the Linux engine
        shell: pwsh
        run: |
          Get-Command docker -All | Format-Table Source -AutoSize | Out-String
          Start-Process -FilePath 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
          $backendLog = "$env:LOCALAPPDATA\Docker\log\host\com.docker.backend.exe.log"
          $stopwatch = [Diagnostics.Stopwatch]::StartNew()
          $osType = $null
          while ($stopwatch.Elapsed.TotalMinutes -lt 10) {
              $osType = docker info --format '{{.OSType}}' 2>&1
              if ($osType -eq 'linux') { break }
              $crash = Select-String -Path $backendLog -Pattern 'backend crashed' -ErrorAction SilentlyContinue
              if ($crash) { throw "Docker Desktop backend crashed: $($crash[0].Line)" }
              "{0,5:N0} s: {1}" -f $stopwatch.Elapsed.TotalSeconds, ($osType | Out-String).Trim()
              Start-Sleep -Seconds 10
          }
          "Engine ready check: OSType=$osType after {0:N1} s" -f $stopwatch.Elapsed.TotalSeconds
          docker context ls
          docker version
          wsl --list --verbose
          if ($osType -ne 'linux') { throw 'Linux engine did not start' }

      - name: Tests (PowerShell 7)
        shell: pwsh
        run: ./scripts/docker-tests.ps1 -ResultFile "$env:RUNNER_TEMP\results.md"

      - name: Tests (Windows PowerShell 5.1)
        if: success() || failure()
        shell: powershell
        run: ./scripts/docker-tests.ps1 -ResultFile "$env:RUNNER_TEMP\results.md"

      - name: Results table
        if: always()
        shell: pwsh
        run: |
          $table = "| Shell | Test | Result | Seconds |`n|---|---|---|---|`n"
          if (Test-Path "$env:RUNNER_TEMP\results.md") { $table += Get-Content "$env:RUNNER_TEMP\results.md" -Raw }
          $table
          Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $table

      - name: Collect Docker Desktop logs
        if: always()
        shell: pwsh
        run: |
          $logFolder = "$env:RUNNER_TEMP\docker-logs"
          New-Item -ItemType Directory -Force -Path $logFolder | Out-Null
          Copy-Item "$env:ProgramData\DockerDesktop\*.txt" $logFolder -ErrorAction SilentlyContinue
          Copy-Item "$env:LOCALAPPDATA\Docker\log" "$logFolder\localappdata-log" -Recurse -ErrorAction SilentlyContinue
          Get-ChildItem $logFolder -Recurse -File | Format-Table FullName, Length -AutoSize | Out-String -Width 300

      - uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        if: always()
        with:
          name: docker-desktop-logs-${{ github.run_id }}
          path: ${{ runner.temp }}/docker-logs
          if-no-files-found: warn
```

### `.github/workflows/winplaybook-poc.yml` (prova de conceito, 1/1 depois da correção)

```yaml
name: winplaybook-poc

on:
  workflow_dispatch:
    inputs:
      winplaybook-ref:
        description: WinPlaybook commit to test
        default: 31c4691064e7f68962cd41ebddb92fe5c3620111

permissions:
  contents: read

env:
  INSTALLER_URL: https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe
  DOCKER_BIN: C:\Program Files\Docker\Docker\resources\bin

jobs:
  poc:
    runs-on: windows-2025
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1

      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          repository: LeonardoSextare/WinPlaybook
          ref: ${{ inputs.winplaybook-ref }}
          path: winplaybook

      - name: Host summary
        shell: pwsh
        run: |
          "ImageVersion=$env:ImageVersion"
          (Get-CimInstance Win32_Processor).Name
          git -C winplaybook log --oneline -1

      - name: Install Docker Desktop
        shell: pwsh
        run: |
          Invoke-WebRequest -Uri $env:INSTALLER_URL -OutFile "$env:RUNNER_TEMP\DockerDesktopInstaller.exe"
          $process = Start-Process -FilePath "$env:RUNNER_TEMP\DockerDesktopInstaller.exe" -Wait -PassThru `
              -ArgumentList 'install', '--quiet', '--accept-license', '--backend=wsl-2'
          "Installer exit code: $($process.ExitCode)"
          # The installer changes the machine PATH, but this job keeps the PATH it started with.
          Add-Content -Path $env:GITHUB_PATH -Value $env:DOCKER_BIN
          if ($process.ExitCode -ne 0) { exit $process.ExitCode }

      # The preinstalled Windows engine owns \\.\pipe\docker_engine, which Docker Desktop
      # needs for its API proxy; with it running, the Docker Desktop backend crashes.
      - name: Stop the preinstalled Windows engine
        shell: pwsh
        run: |
          Stop-Service -Name docker
          Set-Service -Name docker -StartupType Disabled

      - name: Start Docker Desktop and wait for the Linux engine
        shell: pwsh
        run: |
          Start-Process -FilePath 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
          $backendLog = "$env:LOCALAPPDATA\Docker\log\host\com.docker.backend.exe.log"
          $stopwatch = [Diagnostics.Stopwatch]::StartNew()
          $osType = $null
          while ($stopwatch.Elapsed.TotalMinutes -lt 10) {
              $osType = docker info --format '{{.OSType}}' 2>&1
              if ($osType -eq 'linux') { break }
              $crash = Select-String -Path $backendLog -Pattern 'backend crashed' -ErrorAction SilentlyContinue
              if ($crash) { throw "Docker Desktop backend crashed: $($crash[0].Line)" }
              Start-Sleep -Seconds 10
          }
          "Engine ready check: OSType=$osType after {0:N1} s" -f $stopwatch.Elapsed.TotalSeconds
          if ($osType -ne 'linux') { throw 'Linux engine did not start' }

      - name: WinPlaybook (PowerShell 7)
        shell: pwsh
        run: ./scripts/winplaybook-poc.ps1 -RepositoryPath "$env:GITHUB_WORKSPACE\winplaybook"

      - name: WinPlaybook (Windows PowerShell 5.1)
        if: success() || failure()
        shell: powershell
        run: ./scripts/winplaybook-poc.ps1 -RepositoryPath "$env:GITHUB_WORKSPACE\winplaybook"
```

## 7. Recomendação para os e2e do WinPlaybook

**Usar o `windows-2025` gratuito com Docker Desktop instalado a cada job**,
seguindo o `winplaybook-poc.yml`, com estes cuidados:

1. **Parar o serviço `docker` pré-instalado** antes de iniciar o Docker Desktop
   (erro 2). Sem isso, o backend cai e o job fica preso até o timeout.
2. **Falhar rápido.** Loop de espera com limite e leitura do log do backend,
   mais `timeout-minutes` no job. Enviar os logs do Docker Desktop como artifact
   quando falhar.
3. **`PATH` do job:** acrescentar `C:\Program Files\Docker\Docker\resources\bin`
   via `GITHUB_PATH`. O instalador muda o `PATH` da máquina, mas o job mantém o
   `PATH` com que começou. Com isso, o `docker.exe` do Docker Desktop fica na
   frente do `C:\Windows\system32\docker.exe` (**Medido** pelo
   `Get-Command docker -All`).
4. **Rodar nos dois shells**, `pwsh` e `powershell`. O mesmo argumento chega
   diferente ao container em cada um (seção 3), e o 5.1 tem o comportamento do
   erro 3.
5. **Instalar o Pester 6** no job: o runner só traz o 5.9.0 e o 3.4.0, e as
   regras do projeto usam o Pester 6. O tempo de instalação não foi medido.
6. **Fixar a versão do Docker Desktop.** **Medido:** a versão "latest" mudou de
   4.96.2 para 4.96.3 entre dois runs com uns 12 minutos de diferença. Uma URL
   de build fixa, atualizada pelo Renovate, evita que uma versão nova quebre o
   CI sem aviso. **Suposição:** o formato dessa URL para Windows não foi
   verificado; no Linux, a `docker/desktop-action` usa
   `https://desktop.docker.com/linux/main/amd64/<build>/<arquivo>`.
7. **Decidir sobre o erro 3 no módulo.** É decisão de design: o
   `Invoke-AnsibleContainer` pode usar `$ErrorActionPreference = 'Continue'` só
   em volta da chamada ao `docker`, para que avisos do Ansible no stderr não
   interrompam usuários do 5.1 que usam `Stop`. Nos testes do CI, definir
   `Continue` no escopo global, como no `winplaybook-poc.ps1`.

### Otimizações

| Otimização | Ganho esperado | Base |
|---|---|---|
| Iniciar o Docker Desktop e, **enquanto o motor sobe**, instalar o Pester e rodar os testes unitários; esperar `OSType=linux` só antes dos e2e | até 44 a 84 s por job | **Medido:** tempo de motor pronto. **Suposição:** quanto dá para sobrepor |
| Rodar os e2e só quando `module/**` ou `image/**` mudar (filtro de caminho) | job inteiro quando nada relevante mudou | — |
| Cache do instalador | **nenhum, provavelmente negativo** | **Medido:** o download leva de 2,3 a 3,4 s, e o cache do Actions restaurou a 108 MB/s. **Suposição:** restaurar 612 MB levaria cerca de 6 s |
| Cache da pasta instalada | não recomendado | **Suposição:** o instalador também registra serviço, grupo, registro e integração com o WSL; restaurar só a pasta seria frágil |

### Riscos

- **Sem suporte oficial.** A
  [documentação do Docker](https://docs.docker.com/desktop/setup/install/windows-install/):
  *"Docker Desktop is not supported on server versions of Windows, such as
  Windows Server 2019 or Windows Server 2022."* O 2025 não é citado, mas é
  Server. Hoje funciona; um release futuro pode bloquear a instalação.
- **Virtualização aninhada.** Tudo depende do WSL2 subir dentro da VM do runner.
  O KB5127648, com relatos de quebra em AMD (microsoft/WSL#41955, #41947,
  #41917), **não estava** em nenhum host observado. Não sabemos o que acontece
  quando a imagem do runner o incluir.
- **O ambiente muda sozinho.** Em um dia vimos três versões de imagem, com
  patches e versões de WSL diferentes, e quatro modelos de CPU. Uma falha
  intermitente pode vir de um host específico; o passo "Host summary" ajuda a
  diagnosticar.

### Licença

A [página de licença do Docker Desktop](https://docs.docker.com/subscription/desktop-license/)
diz que o uso é gratuito para *"Non-commercial open source projects"*, além de
uso pessoal, educação e pequenas empresas (menos de 250 funcionários e menos de
US$ 10 milhões de receita anual). A página **não menciona CI**. A
`docker/desktop-action` lembra que o uso *"is subject to Docker Desktop license
agreement"*.

## 8. Outras respostas levantadas durante a exploração

- **`setup-wsl` e a distro.** A action não instala nem liga o WSL. Segundo o
  README, os runners Windows já trazem o WSL2, mas *"there is no Linux
  distribution installed by default"*. O papel dela é instalar e configurar uma
  distro, e o input `distribution` sempre tem valor (padrão `Debian-13`). O
  Docker Desktop não precisa dela: cria a própria distro, `docker-desktop`
  (**Medido**: `docker-desktop Running 2`, sem `setup-wsl` no workflow).
- **Action oficial do Docker Desktop.** A
  [`docker/desktop-action`](https://github.com/docker/desktop-action) (v0.4.4) é
  experimental e, pelo README, suporta *"'linux' nodes (ubuntu-latest)"*; o
  código tem ramos para Linux e macOS, nenhum para Windows. A
  [`docker/setup-docker-action`](https://github.com/docker/setup-docker-action)
  (v5.6.0) instala o Docker CE, não o Desktop.
- **Docker CE ou Docker Desktop.** O Docker CE para Windows (o pré-instalado)
  só roda containers Windows (erro 1). O Docker CE para Linux dentro de um
  Ubuntu do WSL2 roda containers Linux, mas sem a "cola" do Desktop: o pipe no
  Windows e a tradução de `C:\...`. **Suposição:** com ele, o módulo teria de
  converter caminhos para `/mnt/c/...` e conectar o `docker.exe` ao motor via
  `DOCKER_HOST`. Não foi testado (passo 5).
- **Runners Windows "desktop".** A
  [lista de imagens](https://github.com/actions/runner-images) só tem Windows
  Server x64 (`windows-2025`, `windows-2022`) e **Windows 11 arm64**
  (`windows-11-arm`). Não existe Windows 10 ou 11 x64 hospedado. A alternativa
  é um runner self-hosted, com o risco de PRs de terceiros rodarem código na
  máquina num repositório público.

## 9. O que ficou sem resposta

- **Efeito do KB5127648:** nenhum host tinha o update.
- **Estabilidade da prova de conceito:** só 1 execução depois da correção,
  abaixo das 3 pedidas.
- **Estabilidade ao longo do tempo:** todas as execuções foram no mesmo dia,
  num intervalo de cerca de 1 hora.
- **Passo 5 (Docker CE no WSL2):** não executado, porque o passo 4 funcionou.
  O que acontece com `--volume C:\temp\projeto` e `/mnt/c/temp/projeto` nesse
  cenário continua sem medição.
- **Usuário sem privilégio de administrador:** o job roda como `runneradmin`,
  administrador; o acesso ao pipe por um usuário comum só no `docker-users` não
  foi testado.
- **Erro 3 fora do CI:** não testado num console interativo nem com `Stop`
  definido pelo usuário.
- **Formato da URL para fixar a versão do Docker Desktop no Windows:** não
  verificado.
- **Tempo de instalação do Pester 6 no runner:** não medido.
- **`windows-11-arm`:** Docker Desktop e virtualização aninhada não testados
  nesse runner.
- **winget e chocolatey:** não testados.
