const fs = require('fs');
const content = fs.readFileSync('lib/core/services/database_service.dart', 'utf8');
let depth = 0;
let lines = content.split('\n');
for (let i = 0; i < lines.length; i++) {
    let line = lines[i];
    let lineNum = i + 1;
    
    let oldDepth = depth;
    for (let char of line) {
        if (char === '{') depth++;
        if (char === '}') depth--;
    }
    
    if (line.match(/Future<.*> .*\(.*\).*\{/)) {
        console.log(`Line ${lineNum}: start_depth=${oldDepth}, end_depth=${depth}, content=${line.trim()}`);
    }
}
console.log(`Final depth: ${depth}`);
