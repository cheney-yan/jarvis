# Jarvis 
## Prepare

1. Source `jarvis.sh` in your `.bashrc` or `.bash_profile` or zshrc:
   ```bash
   source /path/to/jarvis/jarvis.sh
   ```
2. Ensure you have the `llm` Python package installed (see original README for details). You have the choice to use any llm package that supports, but by default I configured to use llm-grok -- where you get abundant free token to use if you sign up with XAI to sell some of your data: https://docs.x.ai/docs/data-sharing.


- Installing llm https://llm.datasette.io/en/stable/setup.html
- Installing llm-grok https://github.com/Hiepler/llm-grok

## Commands

### Default command

Just run `@jarvis` with your command, and follow the instruction.

```text

❯ @jarvis set a cron to run on computer start: ls -ltra

👋 I have some suggestion to your request:
a|👍 Accept) Run: (crontab -l 2>/dev/null; echo "@reboot ls -ltra") | crontab -
d|🖐️ Deny)   Run: set a cron to run on computer start: ls -ltra
s|📑 Save)   Save command to history, so you can edit and run later.
Enter your choice (a/s/d): a
===================CMD EXEC STARTED==================
===================CMD EXEC ENDED: 0==================

jarvis on  feature/simple [✘!?] took 9s
❯ crontab -l
@reboot ls -ltra

```

If @jarvis thinks the command is right, or llm fails, then it will execute the command directly!

If execution fails, @jarvis also analyze it and gives you suggestions. 
```text

❯ JARVIS_LLM_MODEL=gpt-4o-mini @jarvis check my disk size

👋 I have some suggestion to your request:
a|👍 Accept) Run: df -h
d|🖐️ Deny)   Run: check my disk size
s|📑 Save)   Save command to history, so you can edit and run later.
Enter your choice (a/s/d): d
===================CMD EXEC STARTED==================
bash: check: command not found
===================CMD EXEC ENDED: 127==================
 [🤖 ℹ️ ] The command failed because it is not recognized. To check your disk size, you can use the following command instead:

``bash
df -h
``

This will display the disk usage in a human-readable format.


```

## Use Other models

By default, @jarvis uses `grok-3-mini-fast-latest` as the llm model. Make sure the command `llm -m grok-3-mini-fast-latest 'what is the model of you'` mentions about Elon Musk.

You can set the llm model by setting the environment variable `JARVIS_LLM_MODEL`:

```bash
export JARVIS_LLM_MODEL="gpt-4o-mini"
```

You can use local llm as well, make sure testing if it works.

## Show Debug info

JARVIS_DEBUG = 1  # show debug 
JARVIS_DEBUG = 2  # show trace 

# Contribution




