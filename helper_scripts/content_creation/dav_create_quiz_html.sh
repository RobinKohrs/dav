#!/usr/bin/env bash

# --- Load Shared Configuration ---
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
source "$SCRIPT_DIR/../common/dav_common.sh" || {
    echo "Error: Unable to source dav_common.sh"
    exit 1
}

# --- Script Configuration ---
SCRIPT_NAME="quiz-html-creator"

# --- Helper Functions ---
check_dependency() {
  command -v "$1" >/dev/null 2>&1 || {
    gum style --foreground="red" "Error ($SCRIPT_NAME): Dependency '$1' not found." \
              "Please install it to use this script." \
              "(e.g., check $(gum style --underline "$2"))"
    exit 1
  }
}

print_success_qhc() { # QHC for Quiz HTML Creator to avoid clashes if sourced
  gum style --border="double" --border-foreground="green" --padding="1 2" \
            "Success ($SCRIPT_NAME)!" "$1" "HTML file: $(gum style --bold "$2")"
}

print_error_qhc() {
  gum style --foreground="red" "Error ($SCRIPT_NAME): $1"
  exit 1
}

# --- Dependency Checks ---
check_dependency "gum" "https://github.com/charmbracelet/gum"

# Check for clipboard utilities (optional)
has_pbcopy() { command -v pbcopy >/dev/null 2>&1; }
has_xclip() { command -v xclip >/dev/null 2>&1; }
has_clipboard() { has_pbcopy || has_xclip; }

# --- Main Script ---
gum style --border normal --padding "0 1" --margin "1 0" --border-foreground 212 \
          "$(gum style --bold --foreground 212 'Quiz HTML Creator') - Generate interactive quiz for CMS embedding"

# Get quiz question
QUIZ_QUESTION=$(gum input --header "Geben Sie Ihre Quiz-Frage ein:" \
                          --placeholder "z.B., Was ist die Hauptstadt von Österreich?" \
                          --width 80)
if [ -z "$QUIZ_QUESTION" ]; then 
  print_error_qhc "Quiz-Frage darf nicht leer sein."
fi

# Get number of answer options
NUM_ANSWERS=$(gum choose "2" "3" "4" "5" --header "Wie viele Antwortmöglichkeiten möchten Sie?" --height 6)
if [ -z "$NUM_ANSWERS" ]; then 
  print_error_qhc "Anzahl der Antworten muss ausgewählt werden."
fi

# Ask about confetti
ENABLE_CONFETTI=$(gum choose "Ja" "Nein" --header "Konfetti-Animation bei richtiger Antwort?" --height 4)
if [ -z "$ENABLE_CONFETTI" ]; then 
  ENABLE_CONFETTI="Ja"  # Default to yes
fi

# Ask about additional info text
ENABLE_INFO_TEXT=$(gum choose "Ja" "Nein" --header "Zusätzliche Information bei richtiger Antwort anzeigen?" --height 4)
if [ -z "$ENABLE_INFO_TEXT" ]; then 
  ENABLE_INFO_TEXT="Nein"  # Default to no
fi

INFO_TEXT=""
if [[ "$ENABLE_INFO_TEXT" == "Ja" ]]; then
  INFO_TEXT=$(gum input --header "Zusätzliche Information (erscheint bei richtiger Antwort):" \
                        --placeholder "z.B., Wussten Sie, dass..." \
                        --width 80)
fi

# Collect answer options
declare -a ANSWERS
declare -a ANSWER_LETTERS
ANSWER_LETTERS=("A" "B" "C" "D" "E")

gum format -- "- Geben Sie nun die $NUM_ANSWERS Antwortmöglichkeiten ein:"
for ((i=0; i<NUM_ANSWERS; i++)); do
  ANSWER=$(gum input --header "Antwort ${ANSWER_LETTERS[$i]}:" \
                     --placeholder "Antwortmöglichkeit eingeben..." \
                     --width 80)
  if [ -z "$ANSWER" ]; then 
    print_error_qhc "Antwortmöglichkeit ${ANSWER_LETTERS[$i]} darf nicht leer sein."
  fi
  ANSWERS[$i]="$ANSWER"
done

# Select correct answer
gum format -- "- Wählen Sie die richtige Antwort aus:"

CORRECT_ANSWER_LETTER=$(gum choose "${ANSWER_LETTERS[@]:0:$NUM_ANSWERS}" \
                                   --header "Welche Antwort ist richtig?" \
                                   --height $((NUM_ANSWERS + 2)))
if [ -z "$CORRECT_ANSWER_LETTER" ]; then 
  print_error_qhc "Richtige Antwort muss ausgewählt werden."
fi

# Select background color from Der Standard themes
gum format -- "- Wählen Sie ein Farbthema von Der Standard:"
THEME_CHOICE=$(gum choose "APO (#c1d9d9)" "Chripo (#d7e3e8)" "Wirtschaft (#d8dec1)" "Pano/Features (#aed4ae)" "Etat (#ffcc66)" "Lifestyle (#ffffff)" "Karriere (#f8f8f8)" "Wissenschaft (#bedae3)" "Eigene Farbe" \
                         --header "Der Standard Farbthema auswählen:" \
                         --height 10)
if [ -z "$THEME_CHOICE" ]; then 
  print_error_qhc "Farbthema muss ausgewählt werden."
fi

# Handle theme selection
BG_COLOR_HEX="#f8f8f8"  # Default (Karriere)
case "$THEME_CHOICE" in
  "APO"*) BG_COLOR_HEX="#c1d9d9" ;;
  "Chripo"*) BG_COLOR_HEX="#d7e3e8" ;;
  "Wirtschaft"*) BG_COLOR_HEX="#d8dec1" ;;
  "Pano/Features"*) BG_COLOR_HEX="#aed4ae" ;;
  "Etat"*) BG_COLOR_HEX="#ffcc66" ;;
  "Lifestyle"*) BG_COLOR_HEX="#ffffff" ;;
  "Karriere"*) BG_COLOR_HEX="#f8f8f8" ;;
  "Wissenschaft"*) BG_COLOR_HEX="#bedae3" ;;
  "Eigene Farbe")
    CUSTOM_COLOR=$(gum input --header "Eigene Hex-Farbe eingeben (z.B., #ff6b6b):" \
                             --placeholder "#ff6b6b" \
                             --width 20)
    if [[ "$CUSTOM_COLOR" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
      BG_COLOR_HEX="$CUSTOM_COLOR"
    else
      gum style --foreground="yellow" "Ungültiges Hex-Farbformat. Verwende Standard Karriere-Thema."
      BG_COLOR_HEX="#f8f8f8"
    fi
    ;;
esac

# Convert letter to index
CORRECT_ANSWER_INDEX=0
for ((i=0; i<NUM_ANSWERS; i++)); do
  if [ "${ANSWER_LETTERS[$i]}" = "$CORRECT_ANSWER_LETTER" ]; then
    CORRECT_ANSWER_INDEX=$i
    break
  fi
done

# Generate HTML content
gum format -- "- Generiere Quiz-HTML..."

# Create answer options HTML
ANSWER_OPTIONS_HTML=""
for ((i=0; i<NUM_ANSWERS; i++)); do
  ANSWER_OPTIONS_HTML="$ANSWER_OPTIONS_HTML      <button class=\"dj-quiz-option\" data-answer=\"$i\" role=\"radio\" aria-checked=\"false\" tabindex=\"0\">${ANSWER_LETTERS[$i]}: ${ANSWERS[$i]}</button>\n"
done

# Create the complete HTML content
create_html_content() {
cat << 'HTMLEOF'
<style>
  .dj-quiz-container {
    position: relative;
    width: 100%;
    max-width: 615px;
    font-family: STMatilda Info Variable, system-ui, sans-serif;
    background: $BG_COLOR_HEX;
    border-radius: 16px;
    padding: 20px;
    margin: 20px 0;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.12);
    border: 1px solid rgba(255, 255, 255, 0.2);
    box-sizing: border-box;
  }
  
  .dj-quiz-question {
    font-size: 18px;
    font-weight: 600;
    color: #2c3e50;
    margin-bottom: 20px;
    line-height: 1.4;
    text-align: center;
    text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
  }
  
  .dj-quiz-options {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(min(200px, 100%), 1fr));
    gap: 16px;
    margin-bottom: 0;
    width: 100%;
    box-sizing: border-box;
  }
  
  .dj-quiz-option {
    background: rgba(255, 255, 255, 0.9);
    border: 2px solid var(--quiz-border-color, rgba(0, 0, 0, 0.2));
    border-radius: 8px;
    padding: 12px 16px;
    font-size: 14px;
    font-weight: 500;
    color: #2c3e50;
    cursor: pointer;
    transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
    text-align: center;
    font-family: inherit;
    width: 100%;
    min-width: 0;
    box-sizing: border-box;
    backdrop-filter: blur(10px);
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    position: relative;
    overflow: hidden;
    word-wrap: break-word;
    overflow-wrap: break-word;
  }
  
  .dj-quiz-option::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.4), transparent);
    transition: left 0.5s;
  }
  
  .dj-quiz-option:hover::before {
    left: 100%;
  }
  
  .dj-quiz-option:hover {
    background: var(--quiz-hover-color, rgba(255, 255, 255, 0.95));
    transform: translateY(-1px);
    box-shadow: 0 3px 8px rgba(0, 0, 0, 0.15);
  }
  
  .dj-quiz-option.selected {
    border-color: #007bff;
    background: linear-gradient(135deg, #e7f3ff, #cce7ff);
    color: #004085;
    transform: translateY(-2px) scale(1.01);
    box-shadow: 0 6px 20px rgba(0, 123, 255, 0.3);
  }
  
  .dj-quiz-option.correct {
    border-color: #28a745;
    background: linear-gradient(135deg, #d4edda, #b3e5b8);
    color: #155724;
    animation: dj-correct-pulse 0.6s ease-out;
  }
  
  .dj-quiz-option.incorrect {
    border-color: #dc3545;
    background: linear-gradient(135deg, #f8d7da, #f5c6cb);
    color: #721c24;
    animation: dj-incorrect-shake 0.6s ease-out;
  }
  
  .dj-quiz-option:disabled {
    cursor: not-allowed;
    opacity: 0.7;
  }
  
  .dj-quiz-option:focus {
    outline: 2px solid #007bff;
    outline-offset: 2px;
  }
  
  .dj-quiz-option:focus:not(:focus-visible) {
    outline: none;
  }
  
  .dj-quiz-option:focus-visible {
    outline: 2px solid #007bff;
    outline-offset: 2px;
  }
  

  
  .dj-quiz-overlay {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    display: none;
    align-items: center;
    justify-content: center;
    z-index: 100;
    border-radius: 16px;
    padding: 10px;
    box-sizing: border-box;
  }
  
  .dj-quiz-overlay.show {
    display: flex;
  }
  
  .dj-quiz-result {
    background: white;
    padding: 5px;
    border-radius: 12px;
    text-align: center;
    width: 70%;
    height: 100%;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
    animation: dj-result-popup 0.4s ease-out;
    overflow-y: auto;
    box-sizing: border-box;
  }
  
  .dj-quiz-result.correct {
    border-left: 4px solid #28a745;
  }
  
  .dj-quiz-result.incorrect {
    border-left: 4px solid #dc3545;
  }
  
  .dj-quiz-result-title {
    font-size: 16px;
    font-weight: 700;
    margin-bottom: 8px;
  }
  
  .dj-quiz-result.correct .dj-quiz-result-title {
    color: #155724;
  }
  
  .dj-quiz-result.incorrect .dj-quiz-result-title {
    color: #721c24;
  }
  
  .dj-quiz-result-text {
    font-size: 14px;
    color: #666;
    line-height: 1.4;
  }
  
  .dj-quiz-button-container {
    display: flex;
    gap: 8px;
    margin-top: 12px;
    justify-content: center;
  }
  
    .dj-quiz-retry {
    background: rgba(255, 255, 255, 0.9);
    border: 2px solid var(--quiz-border-color, rgba(0, 0, 0, 0.2));
    border-radius: 8px;
    padding: 12px 16px;
    font-size: 14px;
    font-weight: 500;
    color: #2c3e50;
    cursor: pointer;
    transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
    text-align: center;
    font-family: inherit;
    backdrop-filter: blur(10px);
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    position: relative;
    overflow: hidden;
    word-wrap: break-word;
    overflow-wrap: break-word;
  }

  .dj-quiz-retry:hover {
    background: var(--quiz-hover-color, rgba(255, 255, 255, 0.95));
    transform: translateY(-1px);
    box-shadow: 0 3px 8px rgba(0, 0, 0, 0.15);
  }
  
  .dj-quiz-info-button {
    background: rgba(0, 123, 255, 0.1);
    color: #004085;
    border: 1px solid rgba(0, 123, 255, 0.3);
    border-radius: 6px;
    padding: 8px 12px;
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.3s ease;
    font-family: inherit;
    display: none;
  }
  
  .dj-quiz-info-button:hover {
    background: rgba(0, 123, 255, 0.2);
    border-color: rgba(0, 123, 255, 0.5);
  }
  
  .dj-quiz-info-overlay {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    display: none;
    align-items: center;
    justify-content: center;
    z-index: 110;
    border-radius: 16px;
    padding: 10px;
    box-sizing: border-box;
  }
  
  .dj-quiz-info-overlay.show {
    display: flex;
  }
  
  .dj-quiz-info-content {
    background: white;
    padding: 5px;
    border-radius: 16px;
    width: 70%;
    height: auto;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
    animation: dj-result-popup 0.4s ease-out;
    overflow-y: auto;
    box-sizing: border-box;
    position: relative;
  }
  
  .dj-quiz-info-text {
    font-size: 14px;
    line-height: 1.5;
    color: #2c3e50;
    word-wrap: break-word;
    overflow-wrap: break-word;
    margin-bottom: 16px;
  }
  
    .dj-quiz-close-button {
    position: absolute;
    top: 0;
    right: 0;
    background: rgba(255, 255, 255, 0.9);
    color: #2c3e50;
    border: 2px solid rgba(0, 0, 0, 0.2);
    border-radius: 0 16px 0 16px;
    width: 32px;
    height: 32px;
    cursor: pointer;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 18px;
    font-family: inherit;
    font-weight: bold;
    backdrop-filter: blur(10px);
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }

  .dj-quiz-close-button:hover {
    background: rgba(255, 255, 255, 1);
    box-shadow: 0 3px 12px rgba(0, 0, 0, 0.15);
  }
  
  @keyframes dj-result-popup {
    0% {
      transform: scale(0.8) translateY(20px);
      opacity: 0;
    }
    100% {
      transform: scale(1) translateY(0);
      opacity: 1;
    }
  }
  
  /* Confetti Animation */
  .dj-confetti {
    position: absolute;
    width: 8px;
    height: 8px;
    background: #ff6b6b;
    animation: dj-confetti-fall 3s linear forwards;
    z-index: 150;
    pointer-events: none;
  }
  
  .dj-confetti:nth-child(odd) {
    background: #4ecdc4;
    width: 6px;
    height: 6px;
    animation-duration: 2.5s;
  }
  
  .dj-confetti:nth-child(3n) {
    background: #45b7d1;
    width: 5px;
    height: 5px;
    animation-duration: 3.5s;
  }
  
  .dj-confetti:nth-child(4n) {
    background: #f9ca24;
    width: 7px;
    height: 7px;
    animation-duration: 2.8s;
  }
  
  .dj-confetti:nth-child(5n) {
    background: #6c5ce7;
    width: 6px;
    height: 6px;
    animation-duration: 3.2s;
  }
  
  @keyframes dj-correct-pulse {
    0% { transform: scale(1); }
    50% { transform: scale(1.05); }
    100% { transform: scale(1); }
  }
  
  @keyframes dj-incorrect-shake {
    0%, 100% { transform: translateX(0); }
    10%, 30%, 50%, 70%, 90% { transform: translateX(-3px); }
    20%, 40%, 60%, 80% { transform: translateX(3px); }
  }
  
  @keyframes dj-confetti-fall {
    0% {
      transform: translateY(-10px) rotate(0deg);
      opacity: 1;
    }
    100% {
      transform: translateY(400px) rotate(720deg);
      opacity: 0;
    }
  }
  
  @media (max-width: 600px) {
    .dj-quiz-container {
      padding: 16px;
      margin: 10px 0;
    }
    
    .dj-quiz-question {
      font-size: 16px;
    }
    
    .dj-quiz-option {
      padding: 10px 12px;
      font-size: 13px;
    }
  }
</style>

<div class="dj-quiz-container" role="region" aria-labelledby="quiz-question">
  <div class="dj-quiz-question" id="quiz-question">$QUIZ_QUESTION</div>
  
  <div class="dj-quiz-options" role="radiogroup" aria-labelledby="quiz-question" aria-required="true">
$ANSWER_OPTIONS_HTML  </div>
  
  <div class="dj-quiz-overlay" role="dialog" aria-modal="true" aria-labelledby="result-title">
    <div class="dj-quiz-result">
      <div class="dj-quiz-result-title" id="result-title" aria-live="polite"></div>
      <div class="dj-quiz-result-text" aria-live="polite"></div>
      <div class="dj-quiz-button-container">
        <button class="dj-quiz-retry" aria-describedby="result-title">Nochmal!</button>
        <button class="dj-quiz-info-button" aria-describedby="result-title">Info</button>
      </div>
    </div>
  </div>
  
  <div class="dj-quiz-info-overlay" role="dialog" aria-modal="true" aria-label="Zusätzliche Informationen">
    <div class="dj-quiz-info-content">
      <button class="dj-quiz-close-button" aria-label="Schließen">×</button>
      <div class="dj-quiz-info-text"></div>
    </div>
  </div>
</div>

<script>
(function() {
  const quizContainers = document.querySelectorAll('.dj-quiz-container:not([data-quiz-initialized])');
  const container = quizContainers[quizContainers.length - 1];
  if (!container) return;
  
  container.setAttribute('data-quiz-initialized', 'true');
  
  const options = container.querySelectorAll('.dj-quiz-option');
  const overlay = container.querySelector('.dj-quiz-overlay');
  const resultDiv = container.querySelector('.dj-quiz-result');
  const resultTitle = container.querySelector('.dj-quiz-result-title');
  const resultText = container.querySelector('.dj-quiz-result-text');
  const infoButton = container.querySelector('.dj-quiz-info-button');
  const infoOverlay = container.querySelector('.dj-quiz-info-overlay');
  const infoTextDiv = container.querySelector('.dj-quiz-info-text');
  const closeButton = container.querySelector('.dj-quiz-close-button');
  const retryBtn = container.querySelector('.dj-quiz-retry');
  
  const correctAnswer = $CORRECT_ANSWER_INDEX;
  const enableConfetti = $ENABLE_CONFETTI_JS;
  const infoText = "$INFO_TEXT";
  let selectedAnswer = null;
  let answered = false;
  
  // Function to darken a hex color
  function darkenColor(hex, percent) {
    const num = parseInt(hex.replace("#", ""), 16);
    const amt = Math.round(2.55 * percent);
    const R = (num >> 16) - amt;
    const G = (num >> 8 & 0x00FF) - amt;
    const B = (num & 0x0000FF) - amt;
    return "#" + (0x1000000 + (R < 255 ? R < 1 ? 0 : R : 255) * 0x10000 +
      (G < 255 ? G < 1 ? 0 : G : 255) * 0x100 +
      (B < 255 ? B < 1 ? 0 : B : 255)).toString(16).slice(1);
  }
  
  // Function to lighten a hex color
  function lightenColor(hex, percent) {
    const num = parseInt(hex.replace("#", ""), 16);
    const amt = Math.round(2.55 * percent);
    const R = (num >> 16) + amt;
    const G = (num >> 8 & 0x00FF) + amt;
    const B = (num & 0x0000FF) + amt;
    return "#" + (0x1000000 + (R > 255 ? 255 : R) * 0x10000 +
      (G > 255 ? 255 : G) * 0x100 +
      (B > 255 ? 255 : B)).toString(16).slice(1);
  }
  
  // Set dynamic colors based on background
  const bgColor = "$BG_COLOR_HEX";
  const borderColor = darkenColor(bgColor, 10);
  const hoverColor = lightenColor(bgColor, 15);
  container.style.setProperty('--quiz-border-color', borderColor);
  container.style.setProperty('--quiz-hover-color', hoverColor);
  
  // Function to select an option and immediately submit
  function selectOption(index) {
    if (answered) return;
    
    // Set answered state immediately
    answered = true;
    selectedAnswer = index;
    
    // Remove previous selection and disable all options
    options.forEach((opt, i) => {
      opt.classList.remove('selected');
      opt.setAttribute('aria-checked', 'false');
      opt.setAttribute('tabindex', '-1');
      opt.disabled = true;
      opt.setAttribute('aria-disabled', 'true');
    });
    
    // Select current option
    options[index].classList.add('selected');
    options[index].setAttribute('aria-checked', 'true');
    
    // Small delay to show selection before result
    setTimeout(() => {
      showResult();
    }, 300);
  }
  
  // Function to show the quiz result
  function showResult() {
    // Show correct/incorrect styling
    options.forEach((option, index) => {
      if (index === correctAnswer) {
        option.classList.add('correct');
      } else if (index === selectedAnswer) {
        option.classList.add('incorrect');
      }
    });
    
    // Show result overlay
    const isCorrect = selectedAnswer === correctAnswer;
    
    if (isCorrect) {
      resultDiv.className = 'dj-quiz-result correct';
      resultTitle.textContent = '🎉 Richtig!';
      resultText.textContent = '';
      
      // Show info button if there's info text available
      if (infoText && infoText.trim() !== '') {
        infoButton.style.display = 'block';
        infoTextDiv.textContent = infoText;
      } else {
        infoButton.style.display = 'none';
      }
      
      // Trigger confetti only if enabled
      if (enableConfetti) {
        createConfetti();
      }
    } else {
      const correctAnswerText = options[correctAnswer].textContent;
      resultDiv.className = 'dj-quiz-result incorrect';
      resultTitle.textContent = '❌ Falsch!';
      resultText.textContent = 'Die richtige Antwort war: ' + correctAnswerText;
      infoButton.style.display = 'none';
      infoTextDiv.style.display = 'none';
    }
    
    overlay.classList.add('show');
  }
  
  // Handle option selection
  options.forEach((option, index) => {
    option.addEventListener('click', () => selectOption(index));
    
    // Keyboard navigation
    option.addEventListener('keydown', (e) => {
      if (answered) return;
      
      switch(e.key) {
        case 'Enter':
        case ' ':
          e.preventDefault();
          selectOption(index);
          break;
        case 'ArrowDown':
        case 'ArrowRight':
          e.preventDefault();
          const nextIndex = (index + 1) % options.length;
          options[nextIndex].focus();
          break;
        case 'ArrowUp':
        case 'ArrowLeft':
          e.preventDefault();
          const prevIndex = (index - 1 + options.length) % options.length;
          options[prevIndex].focus();
          break;
      }
    });
  });
  
  // Handle info button
  infoButton.addEventListener('click', () => {
    overlay.classList.remove('show');
    infoOverlay.classList.add('show');
  });
  
  // Handle back arrow
  closeButton.addEventListener('click', () => {
    infoOverlay.classList.remove('show');
    overlay.classList.add('show');
  });
  
  // Handle retry button
  retryBtn.addEventListener('click', () => {
    // Reset quiz state
    answered = false;
    selectedAnswer = null;
    
    // Reset UI and accessibility states
    options.forEach((option, index) => {
      option.classList.remove('selected', 'correct', 'incorrect');
      option.disabled = false;
      option.setAttribute('aria-disabled', 'false');
      option.setAttribute('aria-checked', 'false');
      option.setAttribute('tabindex', index === 0 ? '0' : '-1');
    });
    
    overlay.classList.remove('show');
    infoOverlay.classList.remove('show');
    infoButton.style.display = 'none';
    
    // Focus first option for keyboard users
    options[0].focus();
  });
  
  // Confetti function
  function createConfetti() {
    const confettiCount = 30;
    
    for (let i = 0; i < confettiCount; i++) {
      setTimeout(() => {
        const confetti = document.createElement('div');
        confetti.className = 'dj-confetti';
        confetti.style.left = Math.random() * 100 + '%';
        confetti.style.top = '-10px';
        confetti.style.animationDelay = Math.random() * 0.5 + 's';
        
        container.appendChild(confetti);
        
        // Remove confetti after animation
        setTimeout(() => {
          if (confetti.parentNode) {
            confetti.parentNode.removeChild(confetti);
          }
        }, 3500);
      }, i * 50);
    }
  }
})();
</script>
HTMLEOF
}

# Generate the HTML content
HTML_CONTENT=$(create_html_content)

# Convert confetti setting to JavaScript boolean
if [[ "$ENABLE_CONFETTI" == "Ja" ]]; then
  ENABLE_CONFETTI_JS="true"
else
  ENABLE_CONFETTI_JS="false"
fi

# Escape info text for JavaScript
INFO_TEXT_ESCAPED=$(echo "$INFO_TEXT" | sed 's/"/\\"/g' | sed "s/'/\\'/g")

# Now substitute the variables into the HTML content
HTML_CONTENT=$(echo "$HTML_CONTENT" | sed "s|\$BG_COLOR_HEX|$BG_COLOR_HEX|g")
HTML_CONTENT=$(echo "$HTML_CONTENT" | sed "s|\$QUIZ_QUESTION|$QUIZ_QUESTION|g")
HTML_CONTENT=$(echo "$HTML_CONTENT" | sed "s|\$ANSWER_OPTIONS_HTML|$ANSWER_OPTIONS_HTML|g")
HTML_CONTENT=$(echo "$HTML_CONTENT" | sed "s|\$CORRECT_ANSWER_INDEX|$CORRECT_ANSWER_INDEX|g")
HTML_CONTENT=$(echo "$HTML_CONTENT" | sed "s|\$ENABLE_CONFETTI_JS|$ENABLE_CONFETTI_JS|g")
HTML_CONTENT=$(echo "$HTML_CONTENT" | sed "s|\$INFO_TEXT|$INFO_TEXT_ESCAPED|g")

# Ask user for output preference
OUTPUT_OPTIONS=("In Datei speichern" "In Zwischenablage kopieren")
if ! has_clipboard; then
  OUTPUT_OPTIONS=("In Datei speichern")
  gum style --foreground="yellow" "Hinweis: Zwischenablage nicht verfügbar. Speichere in Datei."
fi

if [ ${#OUTPUT_OPTIONS[@]} -gt 1 ]; then
  OUTPUT_CHOICE=$(gum choose "${OUTPUT_OPTIONS[@]}" --header "Wie möchten Sie das HTML erhalten?" --height 4)
else
  OUTPUT_CHOICE="In Datei speichern"
fi

if [[ "$OUTPUT_CHOICE" == "In Datei speichern" ]]; then
  # Get output filename
  DEFAULT_FILENAME="quiz_$(date +%Y%m%d_%H%M%S).html"
  OUTPUT_FILENAME=$(gum input --header "Dateiname:" \
                              --placeholder "quiz.html" \
                              --value "$DEFAULT_FILENAME" \
                              --width 50)
  if [ -z "$OUTPUT_FILENAME" ]; then 
    OUTPUT_FILENAME="$DEFAULT_FILENAME"
  fi
  
  # Ensure .html extension
  if [[ "$OUTPUT_FILENAME" != *.html ]]; then
    OUTPUT_FILENAME="${OUTPUT_FILENAME}.html"
  fi
  
  # Write to file
  echo "$HTML_CONTENT" > "$OUTPUT_FILENAME"
  print_success_qhc "Quiz HTML in Datei gespeichert!" "$OUTPUT_FILENAME"
  
  # Offer to open file
  if gum confirm "Möchten Sie die HTML-Datei zur Vorschau öffnen?" --default=true; then
    if command -v open >/dev/null 2>&1; then
      open "$OUTPUT_FILENAME"
    elif command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$OUTPUT_FILENAME"
    else
      gum style --foreground="yellow" "Konnte Datei nicht automatisch öffnen. Manuell öffnen: $(pwd)/$OUTPUT_FILENAME"
    fi
  fi
  
elif [[ "$OUTPUT_CHOICE" == "In Zwischenablage kopieren" ]]; then
  # Copy to clipboard
  if has_pbcopy; then
    echo "$HTML_CONTENT" | pbcopy
    gum style --border="double" --border-foreground="green" --padding="1 2" \
              "Erfolg ($SCRIPT_NAME)!" "Quiz HTML in Zwischenablage kopiert!" "Bereit zum Einfügen in Ihr CMS"
  elif has_xclip; then
    echo "$HTML_CONTENT" | xclip -selection clipboard
    gum style --border="double" --border-foreground="green" --padding="1 2" \
              "Erfolg ($SCRIPT_NAME)!" "Quiz HTML in Zwischenablage kopiert!" "Bereit zum Einfügen in Ihr CMS"
  else
    gum style --foreground="red" "Fehler: Keine Zwischenablage gefunden. Speichere in Datei."
    # Fallback to file
    DEFAULT_FILENAME="quiz_$(date +%Y%m%d_%H%M%S).html"
    echo "$HTML_CONTENT" > "$DEFAULT_FILENAME"
    print_success_qhc "Quiz HTML in Datei gespeichert (Zwischenablage fehlgeschlagen)!" "$DEFAULT_FILENAME"
  fi
else
  print_error_qhc "Ungültige Ausgabewahl."
fi

# Show summary
echo ""
gum format -- "**Quiz Zusammenfassung:**"
gum format -- "- Frage: $QUIZ_QUESTION"
gum format -- "- Anzahl Optionen: $NUM_ANSWERS"
gum format -- "- Richtige Antwort: ${ANSWER_LETTERS[$CORRECT_ANSWER_INDEX]} (${ANSWERS[$CORRECT_ANSWER_INDEX]})"
gum format -- "- Hintergrundfarbe: $BG_COLOR_HEX"
gum format -- "- Konfetti: $ENABLE_CONFETTI"
gum format -- "- Zusatzinfo: $ENABLE_INFO_TEXT"
if [[ -n "$INFO_TEXT" ]]; then
  gum format -- "- Info-Text: $INFO_TEXT"
fi

echo ""
gum style --italic "Das HTML ist bereit für die Einbettung in Ihr CMS. Alle CSS-Klassen verwenden das 'dj-' Präfix wie gewünscht."

exit 0
