# Claude Code Flaws Allow Remote Code Execution and API Key Exfiltration

**Source:** `Claude Code Flaws Allow Remote Code Execution and API Key Exfiltration.pdf`

---

Claude Code Flaws Allow Remote Code Execution and API K...

1 of 7

https://thehackernews.com/2026/02/claude-code-ﬂaws-allo...

sudo apt-get update cyber_news


 Home

 Newsletter



 Webinars

Claude Code Flaws Allow Remote Code Execution and API Key
Exfiltration
 Ravie Lakshmanan

 Feb 25, 2026

Cybersecurity researchers have disclosed multiple security vulnerabilities in Anthropic's Claude
Code, an artificial intelligence (AI)-powered coding assistant, that could result in remote code
execution and theft of API credentials.
"The vulnerabilities exploit various configuration mechanisms, including Hooks, Model Context
Protocol (MCP) servers, and environment variables – executing arbitrary shell commands and
exfiltrating Anthropic API keys when users clone and open untrusted repositories," Check Point
researchers Aviv Donenfeld and Oded Vanunu said in a report shared with The Hacker News.
The identified shortcomings fall under three broad categories -

2/27/26, 12:57 PM

Claude Code Flaws Allow Remote Code Execution and API K...

2 of 7

https://thehackernews.com/2026/02/claude-code-ﬂaws-allo...

◦ No CVE (CVSS score: 8.7) - A code injection vulnerability stemming from a user consent
bypass when starting Claude Code in a new directory that could result in arbitrary code
execution without additional confirmation via untrusted project hooks defined in .claude/
settings.json. (Fixed in version 1.0.87 in September 2025)
◦ CVE-2025-59536 (CVSS score: 8.7) - A code injection vulnerability that allows execution
of arbitrary shell commands automatically upon tool initialization when a user starts
Claude Code in an untrusted directory. (Fixed in version 1.0.111 in October 2025)
◦ CVE-2026-21852 (CVSS score: 5.3) - An information disclosure vulnerability in Claude
Code's project-load flow that allows a malicious repository to exfiltrate data, including
Anthropic API keys. (Fixed in version 2.0.65 in January 2026)
"If a user started Claude Code in an attacker-controller repository, and the repository included a
settings file that set ANTHROPIC_BASE_URL to an attacker-controlled endpoint, Claude Code would
issue API requests before showing the trust prompt, including potentially leaking the user's API keys,"
Anthropic said in an advisory for CVE-2026-21852.
In other words, simply opening a crafted repository is enough to exfiltrate a developer's active API
key, redirect authenticated API traffic to external infrastructure, and capture credentials. This, in turn,
can permit the attacker to burrow deeper into the victim's AI infrastructure.

2/27/26, 12:57 PM

Claude Code Flaws Allow Remote Code Execution and API K...

3 of 7

https://thehackernews.com/2026/02/claude-code-ﬂaws-allo...

Claude Code Hooks RCE Demo

This could potentially involve accessing shared project files, modifying/deleting cloud-stored data,
uploading malicious content, and even generating unexpected API costs.
Successful exploitation of the first vulnerability could trigger stealthy execution on a developer's
machine without any additional interaction beyond launching the project.

2/27/26, 12:57 PM

Claude Code Flaws Allow Remote Code Execution and API K...

4 of 7

https://thehackernews.com/2026/02/claude-code-ﬂaws-allo...

Claude Code API Key Ex�ltration Demo | CVE-2026-21852

CVE-2025-59536 also achieves a similar goal, the main difference being that repository-defined
configurations defined through .mcp.json and claude/settings.json file could be exploited by an
attacker to override explicit user approval prior to interacting with external tools and services through
the Model Context Protocol (MCP). This is achieved by setting the "enableAllProjectMcpServers"
option to true.
"As AI-powered tools gain the ability to execute commands, initialize external integrations, and
initiate network communication autonomously, configuration files effectively become part of the
execution layer," Check Point said. "What was once considered operational context now directly
influences system behavior."
"This fundamentally alters the threat model. The risk is no longer limited to running untrusted code –
it now extends to opening untrusted projects. In AI-driven development environments, the supply
chain begins not only with source code, but with the automation layers surrounding it."
Found this article interesting? Follow us on Google News, Twitter and LinkedIn to read more
exclusive content we post.

 Tweet



Share



Share

2/27/26, 12:57 PM

Claude Code Flaws Allow Remote Code Execution and API K...

5 of 7

https://thehackernews.com/2026/02/claude-code-ﬂaws-allo...

CYBERSECURITY WEBINARS

Hidden Attack Paths You’re Missing

Learn to Find Hidden Vulnerabilities in Autonomous AI Agents
A practical deep dive into securing AI agents against real-world attack paths beyond the model
itself.
Register for Free

Inside the Quantum Threat

Learn Quantum-Safe Practices to Stop Future Decrypt Attacks
Quantum computers could soon break today’s encryption—join Zscaler’s webinar to learn how postquantum cryptography keeps your data safe for the future.
Watch Free Now

Latest News

Malicious Go Crypto Module Steals Passwords,

ScarCruft Uses Zoho WorkDrive and USB Malware to

Deploys Rekoobe Backdoor...

Breach Air-Gapped Networks...

2/27/26, 12:57 PM

Claude Code Flaws Allow Remote Code Execution and API K...

6 of 7

https://thehackernews.com/2026/02/claude-code-ﬂaws-allo...

Trojanized Gaming Tools Spread Java-Based RAT via

Meta Files Lawsuits Against Brazil, China, Vietnam

Browser and Chat Platforms...

Advertisers Over Celeb-Bait Scams...

Cybersecurity Resources

Expert Insights

Videos Articles

AI Won't Break Microsoft 365. Your Security Backlog

The Riskiest Alert Types and Why Enterprise Soc

Will

Doesn’t Triage Them

The Uncomfortable Truth About "More Visibility"

AI Shouldn't Improve Workflows, It Should Replace
Them. Here's How to Do It

2/27/26, 12:57 PM

Claude Code Flaws Allow Remote Code Execution and API K...

7 of 7

https://thehackernews.com/2026/02/claude-code-ﬂaws-allo...

Get Latest News in Your Inbox
Get the latest news, expert insights, exclusive resources, and strategies from industry
leaders – all for free.

Your e-mai address

Connect with us!









Company

Pages

About THN

Webinars

Advertise with us

Awards

Contact

Privacy Policy



 Contact Us

© 2026 The Hacker News. All Rights Reserved.

2/27/26, 12:57 PM

