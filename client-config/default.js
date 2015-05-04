var AgentTypes = {
  'spl'         : { colors: ["#FF0000", "#FFAA00"], student: true,  programme: 'SPL - Sygeplejerskeuddannelsen' },
  'pmu'         : { colors: ["#FFAA00", "#FFFF00"], student: true,  programme: 'PMU - Psykomotorikuddannelsen' },
  'fys'         : { colors: ["#FF00FF", "#FFAAFF"], student: true,  programme: 'FYS - Fysioterapeutuddannelsen' },
  'soc'         : { colors: ["#00DDFF", "#DAFFFF"], student: true,  programme: 'SOC - Socialrådgiveruddannelsen' },
  'paed'        : { colors: ["#F0F9F5", "#F0F9F5"], student: true,  programme: 'PÆD - Pædagoguddannelsen' },
  'div'         : { colors: ["#FF0000", "#FFAA00"], student: true,  programme: 'DIV - Diverse aktiviteter' },
  'diplomS'     : { colors: ["#FF0000", "#FFAA00"], student: true,  programme: 'Diplom S - Diplomuddannelse - Sundhed' },
  'diplomL'     : { colors: ["#FF0000", "#FFAA00"], student: true,  programme: 'Diplom L - Diplomuddannelse - Ledelse' },
  'teacher'     : { colors: ["#0000FF", "#00FFFF"], student: false, programme: 'Teacher' },
  'researcher'  : { colors: ["#DD33FF", "#FF22FF"], student: false, programme: 'Researcher' },
  'janitor'     : { colors: ["#7B5647", "#7B5647"], student: false, programme: 'Janitor' },
  'cook'        : { colors: ["#FF0000", "#FFFF00"], student: false, programme: 'Cook' },
  'admin'       : { colors: ["#0000FF", "#00FFFF"], student: false, programme: 'Admin' },
  'unknown'     : { colors: ["#FFFFFF", "#FFFFFF"], student: false, programme: '' },
}

var EnergyTypes = {
  'social':    { id: 0, color: '#FF0000', intensity: 0.5 },
  'knowledge': { id: 1, color: '#00FF00', intensity: 0.5 },
  'economic':  { id: 2, color: '#0000FF', intensity: 0.5 },
  'power':     { id: 3, color: '#FF9900', intensity: 0.5 },
  'dirt':      { id: 4, color: '#904930', intensity: 0.5 }
};

var RoomTypes = {
  ''         : { label: 'Other'    , color: '#999999', centerColor: '#999999', edgeColor: '#999999' },
  'classroom': { label: 'Classroom', color: '#00FF00', centerColor: '#00FF00', edgeColor: '#00FF00' },
  'toilet'   : { label: 'Toilet'   , color: '#FF0000', centerColor: '#0055DD', edgeColor: '#0055DD' },
  'research' : { label: 'Research' , color: '#FF00FF', centerColor: '#FF00FF', edgeColor: '#FF00FF' },
  'knowledge': { label: 'Knowledge', color: '#FF00FF', centerColor: '#FF00FF', edgeColor: '#FF00FF' },
  'teacher'  : { label: 'Teacher'  , color: '#FF00FF', centerColor: '#FF00FF', edgeColor: '#FF00FF' },
  'admin'    : { label: 'Admin'    , color: '#112f28', centerColor: '#122120', edgeColor: '#3333FF' },
  'closet'   : { label: 'Closet'   , color: '#996600', centerColor: '#996600', edgeColor: '#996600' },
  'food'     : { label: 'Food'     , color: '#FFAA00', centerColor: '#FFAA00', edgeColor: '#FFAA00' },
  'exit'     : { label: 'Exit'     , color: '#FF0000', centerColor: '#FF0000', edgeColor: '#FF0000' },
  'empty'    : { label: 'Empty'    , color: '#000000', centerColor: '#000000', edgeColor: '#000000' },
  'cell'     : { label: 'Cell'     , color: '#696E98', centerColor: '#696E98', edgeColor: '#FF00FF' }
};

var EnergyPaths = [
  //Knowledge (in all views)
  { from: "research", to: "classroom", fromNum: 'all', toNum: 1, energy: "knowledge", multiplier: "agents" },
  { from: "research", to: "exit", fromNum: 'all', toNum: 1, energy: "knowledge", multiplier: "agents" },
  { from: "library", to: "classroom", fromNum: 'all', toNum: 10, energy: "knowledge", multiplier: "agents" },
  { from: "library", to: "exit", fromNum: 'all', toNum: 10, energy: "knowledge", multiplier: "agents" },
  { from: "exit", to: "library", fromNum: 'all', toNum: 1, energy: "knowledge", multiplier: "intensity" },
  { from: "exit", to: "research", fromNum: 'all', toNum: 1, energy: "knowledge", multiplier: "intensity" },
  { from: "exit", to: "teacher", fromNum: 'all', toNum: 1, energy: "knowledge", multiplier: "intensity" },

  //Knowledge (additionally in Macro view)
  { from: "research", to: "knowledgeBlob", fromNum: 'all', toNum: 1, energy: "knowledge", multiplier: "agents" },
  { from: "library", to: "knowledgeBlob", fromNum: 'all', toNum: 10, energy: "knowledge", multiplier: "intensity" },
  { from: "knowledgeBlob", to: "library", fromNum: 'all', toNum: 1, energy: "knowledge", multiplier: "intensity" },
  { from: "knowledgeBlob", to: "research", fromNum: 'all', toNum: 1, energy: "knowledge", multiplier: "intensity" },
  { from: "knowledgeBlob", to: "teacher", fromNum: 'all', toNum: 1, energy: "knowledge", multiplier: "intensity" },

  //Social (in all views)
  { from: "classroom", to: "classroom", fromNum: 'all', toNum: 1, energy: "social", multiplier: "agents" },
  { from: "classroom", to: "exit", fromNum: 'all', toNum: 1, energy: "social", multiplier: "agents" },
  { from: "canteen", to: "exit", fromNum: 'all', toNum: 10, energy: "social", multiplier: "agents" },
  { from: "cafe", to: "exit", fromNum: 'all', toNum: 10, energy: "social", multiplier: "intensity" },
  { from: "exit", to: "canteen", fromNum: 10, toNum: 1, energy: "social", multiplier: "intensity" },
  { from: "exit", to: "cafe", fromNum: 10, toNum: 1, energy: "social", multiplier: "intensity" },

  //Social (additionally in Macro view)
  { from: "classroom", to: "socialBlob", fromNum: 10, toNum: 1, energy: "social", multiplier: "agents" },
  { from: "canteen", to: "socialBlob", fromNum: 10, toNum: 1, energy: "social", multiplier: "agents" },
  { from: "cafe", to: "socialBlob", fromNum: 10, toNum: 1, energy: "social", multiplier: "agents" },
  { from: "socialBlob", to: "classrom", fromNum: 10, toNum: 1, energy: "social", multiplier: "intensity" },
  { from: "socialBlob", to: "canteen", fromNum: 10, toNum: 1, energy: "social", multiplier: "intensity" },
  { from: "socialBlob", to: "cafe", fromNum: 10, toNum: 1, energy: "social", multiplier: "intensity" },

  //Power (in all views)
  { from: "admin", to: "admin", fromNum: 'all', toNum: 1, energy: "power", multiplier: "agents" },
  { from: "admin", to: "classroom", fromNum: 'all', toNum: 1, energy: "power", multiplier: "agents" },
  { from: "admin", to: "teacher", fromNum: 'all', toNum: 1, energy: "power", multiplier: "agents" },
  { from: "admin", to: "exit", fromNum: 'all', toNum: 1, energy: "power", multiplier: "agents" },
  { from: "library", to: "classroom", fromNum: 'all', toNum: 10, energy: "power", multiplier: "agents" },
  { from: "library", to: "exit", fromNum: 'all', toNum: 10, energy: "power", multiplier: "agents" },
  { from: "exit", to: "library", fromNum: 'all', toNum: 1, energy: "power", multiplier: "intensity" },
  { from: "exit", to: "admin", fromNum: 'all', toNum: 1, energy: "power", multiplier: "intensity" },
  { from: "exit", to: "classroom", fromNum: 'all', toNum: 1, energy: "power", multiplier: "intensity" },
  { from: "exit", to: "teacher", fromNum: 'all', toNum: 1, energy: "power", multiplier: "intensity" },

  //Power (additionally in Macro view)
  { from: "admin", to: "powerBlob", fromNum: 'all', toNum: 1, energy: "power", multiplier: "agents" },
  { from: "library", to: "knowledgeBlob", fromNum: 'all', toNum: 1, energy: "power", multiplier: "agents" },
  { from: "powerBlob", to: "library", fromNum: 'all', toNum: 1, energy: "power", multiplier: "intensity" },
  { from: "powerBlob", to: "admin", fromNum: 'all', toNum: 1, energy: "power", multiplier: "intensity" },
  { from: "powerBlob", to: "classroom", fromNum: 'all', toNum: 1, energy: "power", multiplier: "intensity" },
  { from: "powerBlob", to: "teacher", fromNum: 'all', toNum: 1, energy: "power", multiplier: "intensity" },

  //Brown (in all views)
  { from: "research", to: "exit", fromNum: 'all', toNum: 1, energy: "dirt", multiplier: "agents" },
  { from: "classroom", to: "exit", fromNum: 'all', toNum: 1, energy: "dirt", multiplier: "agents" },
  { from: "teacher", to: "exit", fromNum: 'all', toNum: 1, energy: "dirt", multiplier: "agents" },
  { from: "admin", to: "exit", fromNum: 'all', toNum: 1, energy: "dirt", multiplier: "agents" },
  { from: "toilet", to: "exit", fromNum: 'all', toNum: 1, energy: "dirt", multiplier: "agents" },
  { from: "closet", to: "exit", fromNum: 'all', toNum: 1, energy: "dirt", multiplier: "agents" },
  { from: "canteen", to: "exit", fromNum: 'all', toNum: 1, energy: "dirt", multiplier: "agents" },
  { from: "cafe", to: "exit", fromNum: 'all', toNum: 1, energy: "dirt", multiplier: "agents" },
  { from: "library", to: "exit", fromNum: 'all', toNum: 1, energy: "dirt", multiplier: "agents" },
];

var AgentInteractions = [
  //Knowledge Energy
  { from: 'teacher', to: 'student', energy: 'knowledge' },
  { from: 'teacher', to: 'teacher', energy: 'knowledge' },
  { from: 'researcher', to: 'teacher', energy: 'knowledge' },
  { from: 'researcher', to: 'researcher', energy: 'knowledge' },

  //Social Energy
  { from: 'student', to: 'student', energy: 'social' },
  { from: 'student', to: 'cook', energy: 'social' },
  { from: 'student', to: 'janitor', energy: 'social' },
  { from: 'cook', to: 'cook', energy: 'social' },
  { from: 'janitor', to: 'janitor', energy: 'social' },

  //Power Energy
  { from: 'admin', to: 'student', energy: 'social' },
  { from: 'admin', to: 'teacher', energy: 'social' },
  { from: 'admin', to: 'researcher', energy: 'social' },
  { from: 'admin', to: 'cook', energy: 'social' },
  { from: 'admin', to: 'janitor', energy: 'social' },
  { from: 'admin', to: 'admin', energy: 'social' }
];

var Screens = [
  { client_id: '0', showFloor: 'All', cameraDistance: 2.0 },
  { client_id: '1', showFloor: 'A 0', cameraDistance: 0.5 },
  { client_id: '2', showFloor: 'B 1', cameraDistance: 0.5 },
  { client_id: '3', showFloor: 'C 1', cameraDistance: 0.5 },
  { client_id: '4', showFloor: 'C 2', cameraDistance: 0.5 },
  { client_id: '5', showRoom: 'C.230', cameraDistance: 0.15 },
  { client_id: '6', showRoom: 'canteen', cameraDistance: 0.15 },
  { client_id: '7', showRoom: 'library', cameraDistance: 0.15 }
];

var Config = {
  energyTypes: EnergyTypes,
  agentTypes: AgentTypes,
  agentInteractions: AgentInteractions,
  screens: Screens,

  //map
  cellCloseness: 0.00155,
  cellEdgeWidth: 1,
  bgColor: '#312D2D',
  membraneColor: '#EEEEEE',

  agentLineColor: '#000000',
  agentFillColor: '#FFFFFF',
  agentFillColorBasedOnAccentColor: true,
  agentInvertFillAndLineColorBasedOnGender: true,

  roomTypes: RoomTypes,
  energyPaths: EnergyPaths,

  minStudentAge: 18,
  maxStudentAge: 40,

  maxDistortPoints: 100,

  energySpriteSize: 0.5,
  agentSpriteSize: 10,

  energyPointsPerPathLength: 50,
  energyAgentCountStrength: 2,
  energyIntensityStrength: 5,

  cameraRotationDuration: 60*10, //60s*10 = 10min,
  cameraTiltDuration: 60*10,//60s*10 = 10min
  cameraMaxTilt: 2
};

module.exports = Config;