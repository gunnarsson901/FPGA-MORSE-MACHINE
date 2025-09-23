```text
             _____   ________ __________  ____________________          
            /     \  \_____  \\______   \/   _____/\_   _____/          
  ______   /  \ /  \  /   |   \|       _/\_____  \  |    __)_    ______ 
 /_____/  /    Y    \/    |    \    |   \/        \ |        \  /_____/ 
          \____|__  /\_______  /____|_  /_______  //_______  /          
                  \/         \/       \/        \/         \/           
     _____      _____  _________   ___ ___ .___ _______  ___________    
    /     \    /  _  \ \_   ___ \ /   |   \|   |\      \ \_   _____/    
   /  \ /  \  /  /_\  \/    \  \//    ~    \   |/   |   \ |    __)_     
  /    Y    \/    |    \     \___\    Y    /   /    |    \|        \    
  \____|__  /\____|__  /\______  /\___|_  /|___\____|__  /_______  /    
          \/         \/        \/       \/             \/        \/     
```

# intro
This is a FPGA projekt that simply turns button presses into ASCII and
displays it onto a 18x2 LCD

# To recreate this projekt you'll need:
- FPGA, I used the terasic DE0-CV CYCLONE board.
- LCD display, JHD 162A or HD44780. 
- Push button.
- QUARTUS 18.1


# Morse-kodtabell

## Alfabet
| Bokstav | Morse   | Bokstav | Morse   | Bokstav | Morse   |
|---------|---------|---------|---------|---------|---------|
| A       | .-      | K       | -.-     | U       | ..-     |
| B       | -...    | L       | .-..    | V       | ...-    |
| C       | -.-.    | M       | --      | W       | .--     |
| D       | -..     | N       | -.      | X       | -..-    |
| E       | .       | O       | ---     | Y       | -.--    |
| F       | ..-.    | P       | .--.    | Z       | --..    |
| G       | --.     | Q       | --.-    | Å       | .--.-   |
| H       | ....    | R       | .-.     | Ä       | .-.-    |
| I       | ..      | S       | ...     | Ö       | ---     |
| J       | .---    | T       | -       |         |         |

---

## Siffror
| Siffra | Morse    | Siffra | Morse    | Siffra | Morse    |
|--------|----------|--------|----------|--------|----------|
| 1      | .----    | 4      | ....-    | 7      | --...    |
| 2      | ..---    | 5      | .....    | 8      | ---..    |
| 3      | ...--    | 6      | -....    | 9      | ----.    |
| 0      | -----    |        |          |        |          |

---

## Specialtecken & Signaler
| Tecken        | Morse      | Tecken         | Morse        |
|---------------|------------|----------------|--------------|
| Punkt (.)      | .-.-.-     | Apostrof (')   | .----.        |
| Komma (,)      | --..--     | Kolon (:)      | ---...        |
| Parentes (     | -.--.      | Parentes )     | -.--.-        |
| Bindestreck (-)| -....-     | Citat (")      | .-..-.        |
| Åtskillnad (=) | -...-      | Förstått       | ...-.         |
| Lystring       | -.-.-      | Exp slut (VA)  | ..-.-         |
| Vänta (AS)     | .-...      | Nöd (SOS)      | ...---...     |
| Sluttecken (+) | .-.-.      | Repetition (x) | -- --         |
| Felskrivning    | ........   | Verkställ (IX) | ..-..-        |
