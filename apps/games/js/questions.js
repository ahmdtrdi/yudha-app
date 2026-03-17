// ============================================================
//  questions.js  –  Expanded question bank
// ============================================================

const QUESTIONS = {
  math: [
    { q: 'What is 12 × 8?',            options: ['86','96','106','76'],       answer: 1 },
    { q: 'What is √144?',              options: ['11','14','12','13'],        answer: 2 },
    { q: 'What is 25% of 200?',        options: ['40','50','60','25'],        answer: 1 },
    { q: 'What is 7³?',                options: ['343','243','441','314'],    answer: 0 },
    { q: 'What is 15² − 100?',         options: ['115','125','135','145'],    answer: 1 },
    { q: 'What is 3/4 + 1/2?',         options: ['1','5/4','7/4','1/4'],     answer: 1 },
    { q: 'Solve: 2x + 6 = 20, x = ?', options: ['5','6','7','8'],            answer: 2 },
    { q: 'What is 18 ÷ 0.6?',          options: ['3','12','30','108'],        answer: 2 },
    { q: 'What is 45% of 80?',         options: ['32','36','40','44'],        answer: 1 },
    { q: 'What is 2¹⁰?',               options: ['512','1024','2048','256'],  answer: 1 },
    { q: 'What is the GCF of 36 & 48?',options: ['6','8','12','16'],          answer: 2 },
    { q: 'What is (-4) × (-7)?',       options: ['-28','28','-11','11'],      answer: 1 },
    { q: 'Simplify: 5! (5 factorial)', options: ['25','60','120','720'],      answer: 2 },
    { q: 'What is 0.75 as a fraction?',options: ['1/2','2/3','3/4','4/5'],   answer: 2 },
  ],
  science: [
    { q: 'What planet is closest to the Sun?',    options: ['Venus','Mercury','Mars','Earth'],      answer: 1 },
    { q: 'What gas do plants absorb?',             options: ['Oxygen','Hydrogen','CO₂','Nitrogen'], answer: 2 },
    { q: 'How many bones in the human body?',      options: ['186','196','206','216'],               answer: 2 },
    { q: 'Chemical symbol for Gold?',              options: ['Go','Gd','Au','Ag'],                  answer: 2 },
    { q: 'Speed of light (approx.) in km/s?',      options: ['200,000','300,000','400,000','150,000'], answer: 1 },
    { q: 'Powerhouse of the cell?',                options: ['Nucleus','Ribosome','Mitochondria','Vacuole'], answer: 2 },
    { q: "Water's chemical formula?",              options: ['HO','H₂O₂','H₂O','OH'],              answer: 2 },
    { q: 'What is the atomic number of Carbon?',   options: ['4','6','8','12'],                     answer: 1 },
    { q: 'Which planet has the most moons?',       options: ['Jupiter','Saturn','Uranus','Neptune'], answer: 1 },
    { q: 'DNA stands for?',                        options: ['Deoxyribose Nuclear Acid','Deoxyribonucleic Acid','Double Nucleic Acid','Digital Nucleic Array'], answer: 1 },
    { q: 'Chemical symbol for Iron?',              options: ['Ir','Fe','In','Io'],                  answer: 1 },
    { q: 'Which blood type is universal donor?',   options: ['A+','B-','AB+','O-'],                 answer: 3 },
    { q: 'Loudness of sound is measured in?',      options: ['Hertz','Watts','Decibels','Newtons'], answer: 2 },
  ],
  logic: [
    { q: 'Which comes next: 2, 4, 8, 16, __?',   options: ['24','28','32','36'],                   answer: 2 },
    { q: 'If A>B and B>C, then?',                  options: ['C>A','A>C','B=A','C=B'],              answer: 1 },
    { q: 'Odd one out: Cat, Dog, Rose, Fish',       options: ['Cat','Dog','Rose','Fish'],            answer: 2 },
    { q: '4 hours before midnight is?',             options: ['8PM','9PM','10PM','7PM'],             answer: 0 },
    { q: 'Next: 1, 1, 2, 3, 5, 8, __?',           options: ['11','12','13','14'],                  answer: 2 },
    { q: 'If ALL Blorks are Zings, Tim is a Blork — is Tim a Zing?', options: ['No','Yes','Maybe',"Can't tell"], answer: 1 },
    { q: 'What comes after: Monday, Wednesday, Friday, __?',         options: ['Saturday','Sunday','Tuesday','Thursday'], answer: 1 },
    { q: 'Which is different: Circle, Square, Sphere, Triangle?',     options: ['Circle','Square','Sphere','Triangle'], answer: 2 },
    { q: 'Next: 100, 50, 25, 12.5, __?',          options: ['5','6','6.25','7.5'],                  answer: 2 },
    { q: 'If today is Tuesday, what was it 10 days ago?', options: ['Saturday','Sunday','Friday','Monday'], answer: 1 },
    { q: 'Which does NOT belong: 8, 27, 36, 64?', options: ['8','27','36','64'],                    answer: 2 },
    { q: 'A bat and ball cost $1.10. Bat costs $1 more than ball. Ball costs?', options: ['$0.10','$0.05','$0.15','$0.20'], answer: 1 },
  ],
  general: [
    { q: 'How many continents are there?',         options: ['5','6','7','8'],                       answer: 2 },
    { q: 'Which country has the most people?',     options: ['USA','India','China','Russia'],        answer: 2 },
    { q: 'Capital of Japan?',                      options: ['Seoul','Osaka','Kyoto','Tokyo'],      answer: 3 },
    { q: 'How many sides does a hexagon have?',    options: ['5','6','7','8'],                       answer: 1 },
    { q: 'Year World War II ended?',               options: ['1943','1944','1945','1946'],           answer: 2 },
    { q: 'Who painted the Mona Lisa?',             options: ['Picasso','Da Vinci','Monet','Raphael'], answer: 1 },
    { q: 'What is the largest ocean?',             options: ['Atlantic','Indian','Arctic','Pacific'], answer: 3 },
    { q: 'How many strings does a standard guitar have?', options: ['4','5','6','7'],               answer: 2 },
    { q: 'Capital of Australia?',                  options: ['Sydney','Melbourne','Brisbane','Canberra'], answer: 3 },
    { q: 'Which language has the most native speakers?', options: ['English','Mandarin','Spanish','Hindi'], answer: 1 },
    { q: 'How many colors in a rainbow?',          options: ['5','6','7','8'],                       answer: 2 },
    { q: 'What is the smallest prime number?',     options: ['0','1','2','3'],                       answer: 2 },
    { q: 'Which organ pumps blood?',               options: ['Liver','Lung','Brain','Heart'],       answer: 3 },
    { q: 'How many players in a basketball team?', options: ['4','5','6','7'],                       answer: 1 },
  ],
};

function getRandomQuestion(category = 'math') {
  const pool = QUESTIONS[category] || QUESTIONS.math;
  return pool[Math.floor(Math.random() * pool.length)];
}
