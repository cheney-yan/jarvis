#!/usr/bin/env python3
"""
LLM handler for Jarvis using simonw/llm package.
Processes commands and provides explanations using local LLMs.
"""

import json
import sys
import argparse
from pathlib import Path
import llm

def process_query(query: str) -> str:
    """Process a custom query using llm and return only the refined command as plain text, or empty string on error."""
    try:
        system_prompt = """
You are a shell command processor. Your task is to analyze shell commands and suggest corrections.

Output ONLY a JSON object in this format:
{
    "is_command": true/false,
    "refined": "corrected command if needed",
    "explanation": "brief explanation of what changed and why"
}

Rules:
1. If input is a valid command: set is_command=true and make refined same as input
2. If input needs fixing: set is_command=false and provide corrected command
3. Always provide a brief, friendly explanation
4. NEVER include any text outside the JSON object
5. NEVER use markdown formatting in the explanation
6. Do not use code blocks or backticks
"""
        prompt = f"Process this shell input: {query}"
        import subprocess
        import json
        cmd = ["llm", "-s", system_prompt, prompt, "--no-stream", "--no-log", "-x"]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode != 0:
            return ""
        try:
            llm_output = json.loads(result.stdout.strip())
            is_command = llm_output.get("is_command", False)
            refined_cmd = llm_output.get("refined", "").strip()
            if is_command and refined_cmd:
                return refined_cmd
            elif not is_command and refined_cmd:
                return refined_cmd
            else:
                return ""
        except Exception:
            return ""
    except Exception:
        return ""

def explain_command(command: str, status: int, output: str, error: str) -> dict:
    """Explain a command execution result."""
    try:
        # Create a prompt for command explanation
        system_prompt = "You are a shell command expert. Explain command execution results in a clear and concise way."
        prompt = f"""Explain this command execution result:
Command: {command}
Status: {status}
Output: {output}
Error: {error}"""
        # Run llm command with system prompt
        cmd = ["llm", "-s", system_prompt, prompt]
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            error = result.stderr.strip() or "LLM command failed"
            return {
                "success": False,
                "explanation": None,
                "error": error
            }
        
        explanation = result.stdout.strip()
        if not explanation:
            return {
                "success": False,
                "explanation": None,
                "error": "LLM returned empty explanation"
            }
        
        return {
            "success": True,
            "explanation": explanation,
            "error": None
        }
    except Exception as e:
        error_msg = f"LLM error: {str(e)}"
        print(error_msg, file=sys.stderr)
        return {
            "success": False,
            "explanation": None,
            "error": error_msg
        }

def explain_failure(command: str, status: int, error: str) -> dict:
    """Explain why a command failed."""
    try:
        # Create a prompt for failure analysis
        system_prompt = "You are a shell command expert. Explain why commands fail and suggest potential fixes."
        prompt = f"""Explain why this command failed and suggest how to fix it:
Command: {command}
Status: {status}
Error: {error}"""
        # Run llm command with system prompt
        cmd = ["llm", "-s", system_prompt, prompt]
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            error = result.stderr.strip() or "LLM command failed"
            return {
                "success": False,
                "explanation": None,
                "error": error
            }
        
        explanation = result.stdout.strip()
        if not explanation:
            return {
                "success": False,
                "explanation": None,
                "error": "LLM returned empty explanation"
            }
        
        return {
            "success": True,
            "explanation": explanation,
            "error": None
        }
    except Exception as e:
        error_msg = f"LLM error: {str(e)}"
        print(error_msg, file=sys.stderr)
        return {
            "success": False,
            "explanation": None,
            "error": error_msg
        }

def main():
    parser = argparse.ArgumentParser(description="LLM handler for Jarvis")
    parser.add_argument("action", choices=["process", "explain", "failure"])
    parser.add_argument("--query", help="Query to process")
    parser.add_argument("--command", help="Command to explain")
    parser.add_argument("--status", type=int, help="Command status")
    parser.add_argument("--output", help="Command output")
    parser.add_argument("--error", help="Error output")
    
    args = parser.parse_args()
    
    if args.action == "process":
        if not args.query:
            sys.exit(1)
        refined = process_query(args.query)
        if refined:
            print(refined)
            sys.exit(0)
        else:
            sys.exit(1)
    elif args.action == "explain":
        if not all([args.command, args.status is not None]):
            print(json.dumps({"success": False, "error": "Command and status required for explain action"}))
            return
        result = explain_command(args.command, args.status, args.output or "", args.error or "")
        print(json.dumps(result))
    elif args.action == "failure":
        if not all([args.command, args.status is not None]):
            print(json.dumps({"success": False, "error": "Command and status required for failure action"}))
            return
        result = explain_failure(args.command, args.status, args.error or "")
        print(json.dumps(result))

if __name__ == "__main__":
    main()
