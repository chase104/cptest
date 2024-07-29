/**
 * @module migration-lib
 */
const fs = require('fs')
const path = require('path')
const models = require('./models/index.js')
const moment = require('moment')
const { performance } = require('perf_hooks')

const self = module.exports = {
  init: () => {
    self.appContext = require('app-context').init(require('./config'))
    self.appLib = require('app-lib')
    self.appLib.init()
    self.sharedLib = require('shared-lib')
    require('./services/index').init()
  },
  models,
  execScriptString: async (scriptString) => {
    return models.sequelize.query('SET SQL_SAFE_UPDATES = 0; ' + scriptString, { type: models.Sequelize.QueryTypes.RAW })
  },
  execScriptFile: async (scriptName) => {
    let filePath = path.join(__dirname, 'sql', scriptName);
    
    if (!fs.existsSync(filePath)) {
      const fileNameWithoutExtension = scriptName.slice(0, -4); // Remove the .sql extension
      const oldFileName = `${fileNameWithoutExtension}__old__.sql`;
      filePath = path.join(__dirname, 'sql', oldFileName);
      
      if (!fs.existsSync(filePath)) {
        throw new Error(`Neither ${scriptName} nor ${oldFileName} exists in the sql directory.`);
      }
    }
    
    const scriptContent = fs.readFileSync(filePath, 'utf8');
    return execScriptString(scriptContent);
  },
  getGCSFileToString: async (bucketName, fileName) => {
    if (!self.appContext) {
      self.init()
    }
    const bucket = self.appContext.gcpStorage.bucket(bucketName)
    const file = bucket.file(fileName)
    const fileDownload = await file.download()
    return fileDownload[0].toString('utf8')
  },
  getGCSFileToCSVData: async (bucketName, fileName) => {
    const csvParser = require('papaparse')
    let csvContents = await self.getGCSFileToString(bucketName, fileName)
    return csvParser.parse(csvContents, {
      delimiter: ',',
      header: true
    })
  },
  /**
   * Queries the appropriate MySQL schema tables to determine <columnName> exists in <tableName>
   * @function
   * @name columnExists
   * @param {string} tableName
   * @param {string} columnName
   * @returns {boolean} true if column exists, false if not
   */
  columnExists: async (tableName, columnName) => {
    if (!self.appContext) {
      self.init()
    }

    let modelMgr = self.appContext.requireModelManager()
    let colCount = await modelMgr.sqlScalar('SELECT lf_column_exists(:tableName, :columnName) as col_count;', {tableName, columnName}, 'col_count')
    return !!parseInt(colCount)
  },
  /**
   * Queries system variable from the target DB server
   * @function
   * @name getHostHame
   * @returns {string} return DB server name
   */
  getHostName: async () => {
    if (!self.appContext) {
      self.init()
    }

    let modelMgr = self.appContext.requireModelManager()
    let hostName = await modelMgr.sqlScalar('SELECT @@HOSTNAME as hostname;', {}, 'hostname')
    return hostName
  },
  /**
   * calls an async function <fn> and wraps it with <groupName> messages including time and duration
   * @function
   * @name monitorGroup
   * @param {string} groupName descriptive name of a group of migration statements
   * @param {function} fn async function executing grouped migration statements
   */
  monitorGroup: async (groupName, fn) => {
    let start = performance.now()
    console.log(`[${groupName}] started at: ${moment().format()}`)
    await fn()
    console.log(`[${groupName}] completed at: ${moment().format()}`)
    console.log(`[${groupName}] duration (s): ${(Math.floor(performance.now() - start) / 1000)}`)
  },
  execBQScriptFile: async (scriptName, templateData) => {
    return getService('bigquery').spCreate({source: fs.readFileSync(path.join(__dirname, 'bq-stored-procs/' + scriptName), 'utf8'), templateData})
  }

}
