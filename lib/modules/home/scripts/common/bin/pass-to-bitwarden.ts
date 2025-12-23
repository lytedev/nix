#!/usr/bin/env -S nix shell nixpkgs#deno nixpkgs#pass nixpkgs#bitwarden-cli --command deno run --allow-run --allow-read --allow-env

/**
 * Migrate password-store entries to Bitwarden
 *
 * Usage: pass-to-bitwarden.ts [--dry-run] [--folder <name>]
 *
 * Requires:
 * - pass (password-store) configured and accessible
 * - bw (Bitwarden CLI) installed and logged in
 */

interface PassEntry {
	name: string
	password: string
	username?: string
	url?: string
	notes?: string
	otpUri?: string
}

interface BitwardenLogin {
	organizationId: null
	collectionIds: null
	folderId: string | null
	type: 1
	name: string
	notes: string | null
	favorite: boolean
	login: {
		uris: { match: null; uri: string }[] | null
		username: string | null
		password: string | null
		totp: string | null
	}
}

interface BitwardenItem {
	id: string
	name: string
	type: number
	revisionDate: string
	login?: {
		username: string | null
		password: string | null
	}
}

// Resolve password store directory
const HOME = Deno.env.get('HOME') ?? ''
const XDG_DATA_HOME = Deno.env.get('XDG_DATA_HOME') ?? `${HOME}/.local/share`
const PASSWORD_STORE_DIR = Deno.env.get('PASSWORD_STORE_DIR') ?? `${XDG_DATA_HOME}/password-store`

async function run(
	cmd: string[],
	env?: Record<string, string>,
): Promise<{ stdout: string; success: boolean }> {
	const process = new Deno.Command(cmd[0], {
		args: cmd.slice(1),
		stdout: 'piped',
		stderr: 'piped',
		env: env ? { ...Deno.env.toObject(), ...env } : undefined,
	})
	const { code, stdout, stderr } = await process.output()
	if (code !== 0) {
		const err = new TextDecoder().decode(stderr)
		console.error(`Command failed: ${cmd.join(' ')}`)
		console.error(err)
	}
	return {
		stdout: new TextDecoder().decode(stdout).trim(),
		success: code === 0,
	}
}

async function getPassEntries(): Promise<string[]> {
	const entries: string[] = []

	async function walkDir(dir: string, prefix: string = '') {
		for await (const entry of Deno.readDir(dir)) {
			if (entry.name.startsWith('.')) continue

			const fullPath = `${dir}/${entry.name}`
			const entryName = prefix ? `${prefix}/${entry.name}` : entry.name

			if (entry.isDirectory) {
				await walkDir(fullPath, entryName)
			} else if (entry.name.endsWith('.gpg')) {
				entries.push(entryName.replace(/\.gpg$/, ''))
			}
		}
	}

	await walkDir(PASSWORD_STORE_DIR)
	return entries.sort()
}

function parsePassEntry(name: string, content: string): PassEntry {
	const lines = content.split('\n')
	const password = lines[0] || ''

	const entry: PassEntry = { name, password }

	// Common field patterns
	const fieldPatterns: Record<string, RegExp> = {
		username: /^(user|username|login|email):\s*(.+)$/i,
		url: /^(url|uri|site|website):\s*(.+)$/i,
		otpUri: /^otpauth:\/\/.+$/i,
	}

	const notesLines: string[] = []

	for (let i = 1; i < lines.length; i++) {
		const line = lines[i]
		let matched = false

		// Check for OTP URI (special case - whole line is the value)
		if (fieldPatterns.otpUri.test(line)) {
			entry.otpUri = line
			matched = true
			continue
		}

		// Check other field patterns
		for (const [field, pattern] of Object.entries(fieldPatterns)) {
			if (field === 'otpUri') continue
			const match = line.match(pattern)
			if (match) {
				entry[field as keyof PassEntry] = match[2]
				matched = true
				break
			}
		}

		if (!matched && line.trim()) {
			notesLines.push(line)
		}
	}

	if (notesLines.length > 0) {
		entry.notes = notesLines.join('\n')
	}

	// Try to extract username from entry name if not found
	if (!entry.username) {
		// Pattern: domain/username or service/username
		const nameParts = name.split('/')
		if (nameParts.length >= 2) {
			const lastPart = nameParts[nameParts.length - 1]
			// If last part looks like a username (not a domain)
			if (!lastPart.includes('.') && !lastPart.match(/^(login|main|default|primary)$/i)) {
				entry.username = lastPart
			}
		}
	}

	// Try to infer URL from entry name if not found
	if (!entry.url) {
		const nameParts = name.split('/')
		for (const part of nameParts) {
			if (part.includes('.') && part.match(/\.(com|org|net|io|dev|app|co|me|tv)$/i)) {
				entry.url = `https://${part}`
				break
			}
		}
	}

	return entry
}

async function getPassContent(entryName: string): Promise<string | null> {
	const result = await run(['pass', 'show', entryName], { PASSWORD_STORE_DIR })
	return result.success ? result.stdout : null
}

async function getBitwardenFolderId(folderName: string, sessionKey: string): Promise<string | null> {
	const result = await run(['bw', 'list', 'folders', '--session', sessionKey])
	if (!result.success) return null

	const folders = JSON.parse(result.stdout) as { id: string; name: string }[]
	const folder = folders.find((f) => f.name === folderName)

	if (folder) return folder.id

	// Create folder if it doesn't exist
	const createResult = await run([
		'bw',
		'create',
		'folder',
		btoa(JSON.stringify({ name: folderName })),
		'--session',
		sessionKey,
	])
	if (createResult.success) {
		const created = JSON.parse(createResult.stdout) as { id: string }
		return created.id
	}

	return null
}

function toBitwardenItem(entry: PassEntry, folderId: string | null): BitwardenLogin {
	return {
		organizationId: null,
		collectionIds: null,
		folderId,
		type: 1, // Login type
		name: entry.name,
		notes: entry.notes ?? null,
		favorite: false,
		login: {
			uris: entry.url ? [{ match: null, uri: entry.url }] : null,
			username: entry.username ?? null,
			password: entry.password,
			totp: entry.otpUri ?? null,
		},
	}
}

async function createBitwardenItem(item: BitwardenLogin, sessionKey: string): Promise<boolean> {
	const encoded = btoa(JSON.stringify(item))
	const result = await run(['bw', 'create', 'item', encoded, '--session', sessionKey])
	return result.success
}

async function getBitwardenItems(sessionKey: string): Promise<BitwardenItem[]> {
	const result = await run(['bw', 'list', 'items', '--session', sessionKey])
	if (!result.success) return []
	return JSON.parse(result.stdout) as BitwardenItem[]
}

async function getPassEntryMtime(entryName: string): Promise<Date> {
	const filePath = `${PASSWORD_STORE_DIR}/${entryName}.gpg`
	const stat = await Deno.stat(filePath)
	return stat.mtime ?? new Date(0)
}

type DuplicateCheck =
	| { status: 'no_match' }
	| { status: 'exact_match' }
	| { status: 'name_match'; bwItem: BitwardenItem; bwNewer: boolean }

function checkDuplicate(entry: PassEntry, passMtime: Date, existingItems: BitwardenItem[]): DuplicateCheck {
	const nameMatches = existingItems.filter(
		(item) => item.type === 1 && item.name === entry.name,
	)

	if (nameMatches.length === 0) {
		return { status: 'no_match' }
	}

	// Check for exact match (same name and password)
	const exactMatch = nameMatches.find((item) => item.login?.password === entry.password)
	if (exactMatch) {
		return { status: 'exact_match' }
	}

	// Name matches but password differs - compare dates
	// Use the most recently updated Bitwarden item
	const mostRecent = nameMatches.reduce((a, b) =>
		new Date(a.revisionDate) > new Date(b.revisionDate) ? a : b
	)
	const bwDate = new Date(mostRecent.revisionDate)
	const bwNewer = bwDate > passMtime

	return { status: 'name_match', bwItem: mostRecent, bwNewer }
}

async function updateBitwardenItem(
	itemId: string,
	entry: PassEntry,
	folderId: string | null,
	sessionKey: string,
): Promise<boolean> {
	// First get the existing item to preserve fields we don't want to overwrite
	const getResult = await run(['bw', 'get', 'item', itemId, '--session', sessionKey])
	if (!getResult.success) return false

	const existing = JSON.parse(getResult.stdout)

	// Update with pass entry data
	existing.name = entry.name
	existing.notes = entry.notes ?? existing.notes
	existing.folderId = folderId ?? existing.folderId
	existing.login = {
		...existing.login,
		username: entry.username ?? existing.login?.username,
		password: entry.password,
		totp: entry.otpUri ?? existing.login?.totp,
		uris: entry.url ? [{ match: null, uri: entry.url }] : existing.login?.uris,
	}

	const encoded = btoa(JSON.stringify(existing))
	const result = await run(['bw', 'edit', 'item', itemId, encoded, '--session', sessionKey])
	return result.success
}

async function checkBitwardenStatus(): Promise<string | null> {
	const result = await run(['bw', 'status'])
	if (!result.success) return null

	const status = JSON.parse(result.stdout) as { status: string }
	if (status.status !== 'unlocked') {
		console.error('Bitwarden vault is not unlocked.')
		console.error('Please run: bw unlock')
		console.error('Then export: export BW_SESSION="..."')
		return null
	}

	const session = Deno.env.get('BW_SESSION')
	if (!session) {
		console.error('BW_SESSION environment variable not set.')
		console.error('Please run: export BW_SESSION="$(bw unlock --raw)"')
		return null
	}

	return session
}

function printHelp() {
	console.log(`pass-to-bitwarden - Migrate password-store entries to Bitwarden

Usage: pass-to-bitwarden.ts [OPTIONS]

Options:
  --write          Actually perform the migration (default is dry-run)
  --folder <name>  Bitwarden folder to import into (default: pass-import)
  --help           Show this help message

Environment:
  PASSWORD_STORE_DIR  Path to password store (default: ~/.local/share/password-store)
  BW_SESSION          Bitwarden session key (required for actual migration)

Examples:
  pass-to-bitwarden.ts                              # dry-run by default
  pass-to-bitwarden.ts --write                      # actually migrate
  pass-to-bitwarden.ts --write --folder "From pass" # migrate to custom folder
`)
}

async function main() {
	const args = Deno.args

	if (args.includes('--help') || args.includes('-h')) {
		printHelp()
		Deno.exit(0)
	}

	const dryRun = !args.includes('--write')
	const folderIdx = args.indexOf('--folder')
	const folderName = folderIdx !== -1 ? args[folderIdx + 1] : 'pass-import'

	console.log('=== Password Store to Bitwarden Migration ===\n')
	console.log(`Password store: ${PASSWORD_STORE_DIR}`)
	console.log(`Bitwarden folder: ${folderName}`)
	console.log(`Mode: ${dryRun ? 'DRY RUN (no changes will be made)' : 'WRITE'}\n`)

	// Check Bitwarden status
	const sessionKey = await checkBitwardenStatus()
	if (!sessionKey) {
		Deno.exit(1)
	}

	// Get folder ID
	let folderId: string | null = null
	if (!dryRun && sessionKey) {
		console.log(`Creating/finding folder: ${folderName}`)
		folderId = await getBitwardenFolderId(folderName, sessionKey)
		if (!folderId) {
			console.error('Failed to get/create folder')
			Deno.exit(1)
		}
	}

	// Fetch existing Bitwarden items for duplicate detection
	let existingItems: BitwardenItem[] = []
	if (sessionKey) {
		console.log('Fetching existing Bitwarden items for duplicate detection...')
		existingItems = await getBitwardenItems(sessionKey)
		console.log(`Found ${existingItems.length} existing items\n`)
	}

	// Get all pass entries
	console.log('Scanning password store...')
	const entries = await getPassEntries()
	console.log(`Found ${entries.length} entries\n`)

	let created = 0
	let updated = 0
	let failed = 0
	let skipped = 0
	let duplicates = 0
	let bwNewer = 0
	const skippedEntries: { name: string; reason: string }[] = []

	const encoder = new TextEncoder()
	for (const entryName of entries) {
		await Deno.stdout.write(encoder.encode(`Processing: ${entryName}... `))

		const content = await getPassContent(entryName)
		if (content === null) {
			console.log('SKIP (could not decrypt)')
			skipped++
			skippedEntries.push({ name: entryName, reason: 'could not decrypt' })
			continue
		}
		if (content.trim() === '') {
			console.log('SKIP (empty)')
			skipped++
			skippedEntries.push({ name: entryName, reason: 'empty' })
			continue
		}

		const parsed = parsePassEntry(entryName, content)
		const passMtime = await getPassEntryMtime(entryName)

		// Check for duplicates
		const dupCheck = checkDuplicate(parsed, passMtime, existingItems)

		if (dupCheck.status === 'exact_match') {
			console.log('SKIP (exact duplicate)')
			duplicates++
			continue
		}

		if (dupCheck.status === 'name_match') {
			if (dupCheck.bwNewer) {
				console.log('SKIP (bitwarden entry is newer)')
				bwNewer++
				continue
			}

			// Pass entry is newer - update Bitwarden
			if (dryRun) {
				console.log('WOULD UPDATE (pass is newer)')
				console.log(`  Password: ${'*'.repeat(Math.min(parsed.password.length, 8))}`)
				if (parsed.username) console.log(`  Username: ${parsed.username}`)
				if (parsed.url) console.log(`  URL: ${parsed.url}`)
				if (parsed.otpUri) console.log(`  TOTP: yes`)
				updated++
				continue
			}

			const success = await updateBitwardenItem(dupCheck.bwItem.id, parsed, folderId, sessionKey!)
			if (success) {
				console.log('UPDATED')
				updated++
			} else {
				console.log('UPDATE FAILED')
				failed++
			}
			continue
		}

		// No match - create new entry
		if (dryRun) {
			console.log('WOULD CREATE')
			console.log(`  Password: ${'*'.repeat(Math.min(parsed.password.length, 8))}`)
			if (parsed.username) console.log(`  Username: ${parsed.username}`)
			if (parsed.url) console.log(`  URL: ${parsed.url}`)
			if (parsed.otpUri) console.log(`  TOTP: yes`)
			if (parsed.notes) console.log(`  Notes: ${parsed.notes.substring(0, 50)}...`)
			created++
			continue
		}

		const bwItem = toBitwardenItem(parsed, folderId)
		const createSuccess = await createBitwardenItem(bwItem, sessionKey!)

		if (createSuccess) {
			console.log('CREATED')
			created++
		} else {
			console.log('CREATE FAILED')
			failed++
		}
	}

	console.log('\n=== Migration Summary ===')
	console.log(`Created: ${created}`)
	console.log(`Updated: ${updated}`)
	console.log(`Exact duplicates: ${duplicates}`)
	console.log(`Bitwarden newer: ${bwNewer}`)
	console.log(`Failed: ${failed}`)
	console.log(`Skipped: ${skipped}`)
	console.log(`Total: ${entries.length}`)

	if (skippedEntries.length > 0) {
		console.log('\n=== Skipped Entries ===')
		for (const entry of skippedEntries) {
			console.log(`  ${entry.name} (${entry.reason})`)
		}
	}

	if (!dryRun && (created > 0 || updated > 0)) {
		console.log('\nRunning vault sync...')
		await run(['bw', 'sync', '--session', sessionKey!])
		console.log('Done!')
	}
}

main()
