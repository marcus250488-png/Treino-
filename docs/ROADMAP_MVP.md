# Meu Treino — evolução do produto

## 1. Situação encontrada no projeto-base

O aplicativo atual é Flutter e funciona principalmente de forma local/offline. Já existem:
- importação de ficha por PDF e associação com exercícios da biblioteca;
- plano semanal e tela de treino;
- execução com séries, carga, descanso, pausa e conclusão parcial/total;
- histórico de sessões, duração e volume;
- avaliação física com peso, altura e medidas, IMC informativo e gráfico;
- meta e registro de consumo de água;
- exercícios personalizados;
- login Google opcional para identificação visual, sem autenticação de servidor.

**Importante:** login Google não significa que exista conta de aluno vinculada a uma academia ou sincronização remota. Os dados atuais ficam no aparelho.

## 2. Decisão de produto para o MVP

Evoluir primeiro o aplicativo do aluno, mantendo o uso individual/local enquanto não houver backend. Não simular agendamento, pagamentos, fila de espera, autorização de professor ou sincronização entre aparelhos sem infraestrutura real.

### MVP local — manter e consolidar
1. Treinos: ficha, treino do dia, detalhes, execução, descanso, pausa/retomada, registro de carga e histórico.
2. Biblioteca: exercícios, grupos musculares, equipamentos e exercícios personalizados.
3. Evolução: avaliações, medidas, histórico e gráficos.
4. Hábitos: água e metas; preparar estrutura para passos e consistência sem alegar leitura de sensores.
5. Perfil e configurações: preferências, privacidade, exportação e exclusão local.
6. Conteúdo: receitas fitness como módulo futuro, com origem e avisos claros.

### Próxima etapa — requer decisões e backend
- cadastro/autenticação real e vínculo aluno–academia–unidade;
- API segura e banco relacional;
- sincronização e isolamento dos dados por academia;
- perfis e permissões de aluno, professor e administrador;
- criação/revisão/publicação de treinos pelo professor;
- agenda, reservas, cancelamento, vagas e fila de espera;
- notificações push operacionais;
- contratos e dados administrativos, somente com integração autorizada.

### Etapas avançadas / dependências externas
- prescrição assistida por IA, com revisão profissional e trilha de aprovação;
- check-in por QR Code/GPS/biometria;
- integração com sensores e plataformas de passos/calorias;
- pagamentos, cobranças e situação financeira;
- armazenamento remoto seguro de fotos/vídeos;
- painel web administrativo e gestão multiacademia.

## 3. Regras obrigatórias do produto

- Não criar feed, curtidas, comentários públicos, seguidores, ranking social ou comunidade.
- Não apresentar IA como diagnóstico ou substituto de profissional.
- Não declarar integração externa como pronta sem credenciais, API e testes.
- Dados de saúde são opcionais, minimizados e protegidos; acesso deve ser por função.
- Qualquer módulo de academia deve respeitar configuração e permissões da unidade.
- O modo offline deve permitir consultar a ficha previamente carregada e sincronizar apenas quando houver backend.

## 4. Arquitetura-alvo

**Aplicativo Flutter** (Android primeiro) → **API HTTPS autenticada** → **banco relacional**.

Entidades previstas:
- `organizations` (academias), `units` (unidades);
- `users`, `memberships`, `roles`, `permissions`;
- `students`, `trainers`;
- `exercises`, `workout_templates`, `workout_days`, `workout_items`;
- `workout_sessions`, `set_logs`;
- `physical_assessments`, `health_habits`;
- `class_types`, `classes`, `bookings`, `waitlist_entries`;
- `contracts`, `plans`, `billing_records`;
- `notifications`, `consents`, `audit_logs`.

Toda entidade pertencente a uma academia deverá carregar `organization_id` e, quando aplicável, `unit_id`. A API deve validar o vínculo e a permissão em cada operação; não confiar apenas em filtros feitos no aplicativo.

## 5. Critérios de aceite por etapa

### MVP local
- importar PDF e revisar exercícios antes de salvar;
- iniciar, pausar, concluir parcialmente e concluir totalmente um treino;
- consultar histórico;
- registrar avaliação e acompanhar gráficos;
- registrar água e alterar meta;
- exportar os dados locais;
- funcionar sem login Google.

### MVP conectado (não implementado nesta etapa)
- aluno acessa somente a academia/unidade autorizada;
- professor cria e publica ficha;
- aluno reserva/cancela aula conforme regras;
- fila de espera respeita capacidade e ordem;
- administrador ativa/desativa módulos;
- testes comprovam isolamento entre academias;
- logs e permissões protegem dados pessoais e de saúde.

## 6. Pendências que precisam de decisão antes do backend

- Nome comercial e identidade visual definitivos.
- Se o primeiro lançamento será somente para uso pessoal ou já para academias clientes.
- Provedor de backend, hospedagem, banco, autenticação e notificações.
- Regras de planos, cobrança, cancelamento, fila de espera e troca de unidade.
- Quem será o controlador dos dados e canal de privacidade/LGPD.
- Quais dados de saúde serão realmente coletados e por qual finalidade.
- Política de retenção, exportação e exclusão de dados.
- Se haverá painel web para professor/administrador.

## 7. Segurança para o repositório

- Não enviar keystore, senhas, `key.properties`, tokens ou arquivos `local.properties`.
- Não incluir dados reais de alunos ou avaliações nos dados de demonstração.
- Usar dados fictícios nos testes.
- Configurar segredos do GitHub em Settings → Secrets and variables → Actions quando integrações forem adicionadas.
