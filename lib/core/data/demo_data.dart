class BiologyDemoData {
  static const String biologyQuiz = r'''
<!doctype html>
<html lang="ar" dir="rtl" class="h-full">
 <head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>اختبار علم الأحياء التفاعلي</title>
  <style>
        body {
            box-sizing: border-box;
        }
        
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        html, body {
            height: 100%;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }

        body {
            background: linear-gradient(135deg, #e8f5e9 0%, #b2dfdb 100%);
            overflow-x: hidden;
        }

        .main-wrapper {
            width: 100%;
            height: 100%;
            overflow-auto;
            position: relative;
        }

        .floating-cells {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            pointer-events: none;
            z-index: 1;
            overflow: hidden;
        }

        .cell {
            position: absolute;
            font-size: 24px;
            opacity: 0.3;
            animation: float 15s infinite ease-in-out;
        }

        @keyframes float {
            0%, 100% {
                transform: translateY(0) translateX(0) rotate(0deg);
            }
            25% {
                transform: translateY(-30px) translateX(20px) rotate(90deg);
            }
            50% {
                transform: translateY(-60px) translateX(-20px) rotate(180deg);
            }
            75% {
                transform: translateY(-30px) translateX(20px) rotate(270deg);
            }
        }

        .container {
            max-width: 800px;
            margin: 0 auto;
            padding: 40px 20px;
            position: relative;
            z-index: 2;
        }

        .quiz-card {
            background: white;
            border-radius: 24px;
            padding: 40px;
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.1);
            margin-bottom: 30px;
        }

        .header {
            text-align: center;
            margin-bottom: 30px;
        }

        .title {
            font-size: 36px;
            color: #2e7d32;
            margin-bottom: 10px;
            font-weight: bold;
        }

        .subtitle {
            font-size: 20px;
            color: #00838f;
            margin-bottom: 20px;
        }

        .progress-section {
            background: linear-gradient(135deg, #c8e6c9 0%, #b2dfdb 100%);
            border-radius: 16px;
            padding: 20px;
            margin-bottom: 30px;
            text-align: center;
        }

        .plant-progress {
            font-size: 48px;
            margin-bottom: 10px;
            display: flex;
            justify-content: center;
            align-items: center;
            gap: 10px;
        }

        .progress-text {
            font-size: 18px;
            color: #2e7d32;
            font-weight: bold;
        }

        .difficulty-selector {
            display: flex;
            gap: 15px;
            justify-content: center;
            margin-bottom: 30px;
            flex-wrap: wrap;
        }

        .difficulty-btn {
            padding: 15px 30px;
            font-size: 18px;
            border: 3px solid #4caf50;
            background: white;
            color: #2e7d32;
            border-radius: 12px;
            cursor: pointer;
            transition: all 0.3s ease;
            font-weight: bold;
        }

        .difficulty-btn:hover {
            background: #4caf50;
            color: white;
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(76, 175, 80, 0.3);
        }

        .difficulty-btn.active {
            background: #4caf50;
            color: white;
        }

        .question-container {
            margin-bottom: 30px;
        }

        .question-header {
            display: flex;
            align-items: center;
            gap: 10px;
            margin-bottom: 20px;
        }

        .question-icon {
            font-size: 32px;
        }

        .question-text {
            font-size: 22px;
            color: #1b5e20;
            font-weight: 600;
        }

        .answers {
            display: flex;
            flex-direction: column;
            gap: 12px;
        }

        .answer-btn {
            padding: 18px 24px;
            font-size: 18px;
            background: #f1f8e9;
            border: 2px solid #aed581;
            border-radius: 12px;
            cursor: pointer;
            transition: all 0.3s ease;
            text-align: right;
            color: #33691e;
            font-weight: 500;
        }

        .answer-btn:hover {
            background: #dcedc8;
            transform: translateX(-5px);
            box-shadow: 0 4px 12px rgba(174, 213, 129, 0.3);
        }

        .answer-btn.correct {
            background: #81c784;
            border-color: #4caf50;
            color: white;
        }

        .answer-btn.wrong {
            background: #ef9a9a;
            border-color: #e57373;
            color: white;
        }

        .answer-btn:disabled {
            cursor: not-allowed;
        }

        .feedback {
            margin-top: 20px;
            padding: 20px;
            border-radius: 12px;
            font-size: 18px;
            text-align: center;
            font-weight: 600;
        }

        .feedback.correct {
            background: #c8e6c9;
            color: #2e7d32;
        }

        .feedback.wrong {
            background: #ffcdd2;
            color: #c62828;
        }

        .start-btn, .next-btn, .retry-btn {
            width: 100%;
            padding: 20px;
            font-size: 22px;
            background: linear-gradient(135deg, #66bb6a 0%, #43a047 100%);
            color: white;
            border: none;
            border-radius: 16px;
            cursor: pointer;
            font-weight: bold;
            transition: all 0.3s ease;
            box-shadow: 0 4px 12px rgba(67, 160, 71, 0.3);
        }

        .start-btn:hover, .next-btn:hover, .retry-btn:hover {
            transform: translateY(-3px);
            box-shadow: 0 6px 20px rgba(67, 160, 71, 0.4);
        }

        .results {
            text-align: center;
        }

        .badge {
            font-size: 80px;
            margin: 30px 0;
            animation: celebrate 2s ease-in-out infinite;
        }

        @keyframes celebrate {
            0%, 100% {
                transform: scale(1) rotate(0deg);
            }
            25% {
                transform: scale(1.1) rotate(-5deg);
            }
            75% {
                transform: scale(1.1) rotate(5deg);
            }
        }

        .badge-title {
            font-size: 32px;
            color: #1b5e20;
            margin-bottom: 20px;
            font-weight: bold;
        }

        .score {
            font-size: 48px;
            color: #00838f;
            margin: 20px 0;
            font-weight: bold;
        }

        .floating-leaves {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            pointer-events: none;
            z-index: 3;
        }

        .leaf {
            position: absolute;
            font-size: 30px;
            animation: fall 4s linear;
        }

        @keyframes fall {
            0% {
                transform: translateY(-100px) rotate(0deg);
                opacity: 1;
            }
            100% {
                transform: translateY(100vh) rotate(360deg);
                opacity: 0;
            }
        }

        .hidden {
            display: none;
        }

        @media (max-width: 600px) {
            .quiz-card {
                padding: 25px;
            }

            .title {
                font-size: 28px;
            }

            .subtitle {
                font-size: 16px;
            }

            .difficulty-selector {
                flex-direction: column;
            }

            .question-text {
                font-size: 18px;
            }

            .answer-btn {
                font-size: 16px;
                padding: 15px 20px;
            }
        }
    </style>
  <script src="https://cdn.tailwindcss.com" type="text/javascript"></script>
 </head>
 <body>
  <div class="floating-cells" id="floatingCells"></div>
  <div class="main-wrapper">
   <div class="container">
    <div class="quiz-card">
     <div class="header">
      <h1 class="title" id="quizTitle">🧬 اختبار علم الأحياء التفاعلي 🔬</h1>
      <p class="subtitle" id="quizSubtitle">اكتشف عجائب علم الأحياء! 🌱</p>
     </div>
     <div id="welcomeScreen">
      <div class="progress-section">
       <div class="plant-progress"><span>🌱</span> <span style="opacity: 0.3;">→</span> <span style="opacity: 0.3;">🌿</span> <span style="opacity: 0.3;">→</span> <span style="opacity: 0.3;">🌳</span>
       </div>
       <p class="progress-text">ساعد النبتة على النمو بالإجابة الصحيحة!</p>
      </div>
      <h3 style="text-align: center; color: #2e7d32; margin-bottom: 20px; font-size: 24px;">اختر مستوى الصعوبة:</h3>
      <div class="difficulty-selector"><button class="difficulty-btn active" onclick="selectDifficulty('easy')"> 🌱 سهل </button> <button class="difficulty-btn" onclick="selectDifficulty('medium')"> 🌿 متوسط </button> <button class="difficulty-btn" onclick="selectDifficulty('hard')"> 🌳 صعب </button>
      </div><button class="start-btn" id="startBtn" onclick="startQuiz()">ابدأ الاختبار 🚀</button>
     </div>
     <div id="quizScreen" class="hidden">
      <div class="progress-section">
       <div class="plant-progress" id="plantProgress"><span id="plant1">🌱</span> <span style="opacity: 0.3;">→</span> <span id="plant2" style="opacity: 0.3;">🌿</span> <span style="opacity: 0.3;">→</span> <span id="plant3" style="opacity: 0.3;">🌳</span>
       </div>
       <p class="progress-text" id="progressText">السؤال 1 من 6</p>
      </div>
      <div class="question-container">
       <div class="question-header"><span class="question-icon" id="questionIcon">🦠</span>
        <h2 class="question-text" id="questionText"></h2>
       </div>
       <div class="answers" id="answersContainer"></div>
       <div id="feedback" class="feedback hidden"></div>
      </div><button class="next-btn hidden" id="nextBtn" onclick="nextQuestion()">التالي ➡️</button>
     </div>
     <div id="resultsScreen" class="hidden">
      <div class="results">
       <div class="badge">
        🔬🧪🧬
       </div>
       <h2 class="badge-title">🎉 عالم أحياء صغير 🎉</h2>
       <div class="plant-progress" style="justify-content: center; margin: 20px 0;"><span style="font-size: 60px;">🌳</span>
       </div>
       <p class="score" id="finalScore"></p>
       <p style="font-size: 20px; color: #2e7d32; margin: 20px 0;" id="resultMessage"></p><button class="retry-btn" id="retryBtn" onclick="resetQuiz()">أعد المحاولة 🔄</button>
      </div>
     </div>
    </div>
   </div>
  </div>
  <script>
        const defaultConfig = {
            quiz_title: "🧬 اختبار علم الأحياء التفاعلي 🔬",
            quiz_subtitle: "اكتشف عجائب علم الأحياء! 🌱",
            start_button_text: "ابدأ الاختبار 🚀",
            next_button_text: "التالي ➡️",
            retry_button_text: "أعد المحاولة 🔄"
        };

        const questions = {
            easy: [
                {
                    icon: "🦠",
                    question: "ما هي أصغر وحدة في الكائن الحي؟",
                    answers: ["الخلية", "العضو", "النسيج", "الجهاز"],
                    correct: 0
                },
                {
                    icon: "🌱",
                    question: "ما اسم العملية التي تصنع بها النباتات غذاءها؟",
                    answers: ["التنفس", "التمثيل الضوئي", "الهضم", "الإخراج"],
                    correct: 1
                },
                {
                    icon: "🧬",
                    question: "أين توجد المادة الوراثية (DNA) في الخلية؟",
                    answers: ["السيتوبلازم", "الغشاء", "النواة", "الميتوكوندريا"],
                    correct: 2
                },
                {
                    icon: "🐾",
                    question: "أي من هذه الحيوانات من الثدييات؟",
                    answers: ["السمكة", "الطائر", "الأفعى", "الدلفين"],
                    correct: 3
                },
                {
                    icon: "🌿",
                    question: "ما هو الغاز الذي تحتاجه النباتات للتمثيل الضوئي؟",
                    answers: ["الأكسجين", "ثاني أكسيد الكربون", "النيتروجين", "الهيدروجين"],
                    correct: 1
                },
                {
                    icon: "🧫",
                    question: "كم عدد الحواس الأساسية للإنسان؟",
                    answers: ["ثلاث", "أربع", "خمس", "ست"],
                    correct: 2
                }
            ],
            medium: [
                {
                    icon: "🦠",
                    question: "ما هي العضية المسؤولة عن إنتاج الطاقة في الخلية؟",
                    answers: ["النواة", "الميتوكوندريا", "الرايبوسومات", "الليسوسومات"],
                    correct: 1
                },
                {
                    icon: "🌱",
                    question: "ما هي الصبغة الخضراء في النباتات المسؤولة عن التمثيل الضوئي؟",
                    answers: ["الهيموغلوبين", "الكلوروفيل", "الكاروتين", "الميلانين"],
                    correct: 1
                },
                {
                    icon: "🧬",
                    question: "كم عدد الكروموسومات في الخلية البشرية؟",
                    answers: ["23", "46", "92", "32"],
                    correct: 1
                },
                {
                    icon: "🐾",
                    question: "ما هي المجموعة التي تضم الأسماك والبرمائيات والزواحف؟",
                    answers: ["الفقاريات", "اللافقاريات", "الثدييات", "الطيور"],
                    correct: 0
                },
                {
                    icon: "🌿",
                    question: "ما هو المنتج الثانوي للتمثيل الضوئي؟",
                    answers: ["ثاني أكسيد الكربون", "الماء", "الأكسجين", "الجلوكوز"],
                    correct: 2
                },
                {
                    icon: "🧫",
                    question: "ما هو نوع الخلايا التي ليس لها نواة محددة؟",
                    answers: ["خلايا حقيقية النواة", "خلايا بدائية النواة", "خلايا نباتية", "خلايا حيوانية"],
                    correct: 1
                }
            ],
            hard: [
                {
                    icon: "🦠",
                    question: "ما هي عملية موت الخلايا المبرمج؟",
                    answers: ["الانقسام الخلوي", "الأبوبتوزيس", "الانقسام الميتوزي", "التمايز"],
                    correct: 1
                },
                {
                    icon: "🌱",
                    question: "في أي جزء من البلاستيدة الخضراء تحدث التفاعلات الضوئية؟",
                    answers: ["الستروما", "الثايلاكويد", "الغشاء الخارجي", "المصفوفة"],
                    correct: 1
                },
                {
                    icon: "🧬",
                    question: "ما هي العملية التي يتم فيها نسخ DNA إلى RNA؟",
                    answers: ["الترجمة", "النسخ", "التضاعف", "الطفرة"],
                    correct: 1
                },
                {
                    icon: "🐾",
                    question: "ما هي الشعبة التي تضم أكبر عدد من الأنواع الحيوانية؟",
                    answers: ["الحبليات", "المفصليات", "الرخويات", "الحلقيات"],
                    correct: 1
                },
                {
                    icon: "🌿",
                    question: "ما اسم الإنزيم الذي يحفز تثبيت ثاني أكسيد الكربون في دورة كالفن؟",
                    answers: ["الكلوروفيل", "روبيسكو", "ATP سينثيز", "NADP+ ريدكتيز"],
                    correct: 1
                },
                {
                    icon: "🧫",
                    question: "ما هو عدد جزيئات ATP الناتجة من جزيء جلوكوز واحد في التنفس الهوائي؟",
                    answers: ["2", "4", "36-38", "100"],
                    correct: 2
                }
            ]
        };

        let currentDifficulty = 'easy';
        let currentQuestionIndex = 0;
        let score = 0;
        let currentQuestions = [];

        function createFloatingCells() {
            const container = document.getElementById('floatingCells');
            const cells = ['🔬', '🦠', '🧫'];
            
            for (let i = 0; i < 15; i++) {
                const cell = document.createElement('div');
                cell.className = 'cell';
                cell.textContent = cells[Math.floor(Math.random() * cells.length)];
                cell.style.left = Math.random() * 100 + '%';
                cell.style.top = Math.random() * 100 + '%';
                cell.style.animationDelay = Math.random() * 5 + 's';
                cell.style.animationDuration = (10 + Math.random() * 10) + 's';
                container.appendChild(cell);
            }
        }

        function selectDifficulty(level) {
            currentDifficulty = level;
            const buttons = document.querySelectorAll('.difficulty-btn');
            buttons.forEach(btn => btn.classList.remove('active'));
            event.target.classList.add('active');
        }

        function startQuiz() {
            currentQuestions = [...questions[currentDifficulty]];
            currentQuestionIndex = 0;
            score = 0;
            
            document.getElementById('welcomeScreen').classList.add('hidden');
            document.getElementById('quizScreen').classList.remove('hidden');
            
            displayQuestion();
        }

        function displayQuestion() {
            const question = currentQuestions[currentQuestionIndex];
            const totalQuestions = currentQuestions.length;
            
            document.getElementById('questionIcon').textContent = question.icon;
            document.getElementById('questionText').textContent = question.question;
            document.getElementById('progressText').textContent = `السؤال ${currentQuestionIndex + 1} من ${totalQuestions}`;
            
            const answersContainer = document.getElementById('answersContainer');
            answersContainer.innerHTML = '';
            
            question.answers.forEach((answer, index) => {
                const button = document.createElement('button');
                button.className = 'answer-btn';
                button.textContent = answer;
                button.onclick = () => checkAnswer(index);
                answersContainer.appendChild(button);
            });
            
            document.getElementById('feedback').classList.add('hidden');
            document.getElementById('nextBtn').classList.add('hidden');
            
            updatePlantProgress();
        }

        function checkAnswer(selectedIndex) {
            const question = currentQuestions[currentQuestionIndex];
            const buttons = document.querySelectorAll('.answer-btn');
            const feedback = document.getElementById('feedback');
            
            buttons.forEach(btn => btn.disabled = true);
            
            if (selectedIndex === question.correct) {
                buttons[selectedIndex].classList.add('correct');
                feedback.textContent = '🎉 إجابة صحيحة! ممتاز!';
                feedback.className = 'feedback correct';
                score++;
            } else {
                buttons[selectedIndex].classList.add('wrong');
                buttons[question.correct].classList.add('correct');
                feedback.textContent = '❌ إجابة خاطئة. الإجابة الصحيحة مميزة باللون الأخضر.';
                feedback.className = 'feedback wrong';
            }
            
            feedback.classList.remove('hidden');
            document.getElementById('nextBtn').classList.remove('hidden');
        }

        function updatePlantProgress() {
            const totalQuestions = currentQuestions.length;
            const progress = (currentQuestionIndex + 1) / totalQuestions;
            
            if (progress >= 0.33) {
                document.getElementById('plant1').style.opacity = '1';
            }
            if (progress >= 0.66) {
                document.getElementById('plant2').style.opacity = '1';
            }
            if (progress >= 1) {
                document.getElementById('plant3').style.opacity = '1';
            }
        }

        function nextQuestion() {
            currentQuestionIndex++;
            
            if (currentQuestionIndex < currentQuestions.length) {
                displayQuestion();
            } else {
                showResults();
            }
        }

        function showResults() {
            document.getElementById('quizScreen').classList.add('hidden');
            document.getElementById('resultsScreen').classList.remove('hidden');
            
            const totalQuestions = currentQuestions.length;
            const percentage = (score / totalQuestions) * 100;
            
            document.getElementById('finalScore').textContent = `${score} من ${totalQuestions} (${Math.round(percentage)}%)`;
            
            let message = '';
            if (percentage >= 90) {
                message = 'رائع! أنت عالم أحياء حقيقي! 🌟';
            } else if (percentage >= 70) {
                message = 'أحسنت! لديك معرفة جيدة بعلم الأحياء! 👏';
            } else if (percentage >= 50) {
                message = 'جيد! استمر في التعلم! 💪';
            } else {
                message = 'لا بأس! حاول مرة أخرى وستتحسن! 📚';
            }
            
            document.getElementById('resultMessage').textContent = message;
            
            createFloatingLeaves();
        }

        function createFloatingLeaves() {
            const container = document.createElement('div');
            container.className = 'floating-leaves';
            document.body.appendChild(container);
            
            for (let i = 0; i < 20; i++) {
                setTimeout(() => {
                    const leaf = document.createElement('div');
                    leaf.className = 'leaf';
                    leaf.textContent = '🍃';
                    leaf.style.left = Math.random() * 100 + '%';
                    leaf.style.animationDuration = (3 + Math.random() * 2) + 's';
                    container.appendChild(leaf);
                    
                    setTimeout(() => leaf.remove(), 4000);
                }, i * 100);
            }
            
            setTimeout(() => container.remove(), 5000);
        }

        function resetQuiz() {
            document.getElementById('resultsScreen').classList.add('hidden');
            document.getElementById('welcomeScreen').classList.remove('hidden');
            
            document.getElementById('plant1').style.opacity = '1';
            document.getElementById('plant2').style.opacity = '0.3';
            document.getElementById('plant3').style.opacity = '0.3';
            
            const buttons = document.querySelectorAll('.difficulty-btn');
            buttons.forEach(btn => btn.classList.remove('active'));
            buttons[0].classList.add('active');
            currentDifficulty = 'easy';
        }

        createFloatingCells();
    </script>
 </body>
</html>
''';
}
