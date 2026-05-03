const fs = require('fs');
const content = fs.readFileSync('lib/core/services/database_service.dart', 'utf8');
let depth = 0;
let lines = content.split('\n');
for (let i = 0; i < 1040; i++) {
    let line = lines[i];
    let lineNum = i + 1;
    for (let char of line) {
        if (char === '{') depth++;
        if (char === '}') depth--;
    }
    if (lineNum >= 1030 && lineNum <= 1035) {
        console.log(`Line ${lineNum}: depth=${depth}, content=${line.trim()}`);
    }
}
