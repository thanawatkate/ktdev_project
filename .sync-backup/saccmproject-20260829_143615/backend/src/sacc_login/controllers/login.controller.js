const login = require('../services/login.service');

async function checkToken(req, res, next) {
  try {
    res.json(await login.checkToken(req.query.token));
  } catch (err) {
    console.error(`Error while getting jwt`, err.message);
    next(err);
  }
}

async function checkTokenEXP(req, res, next) {
  try {
    res.json(await login.checkTokenEXP(req.query.token));
  } catch (err) {
    console.error(`Error while getting jwt`, err.message);
    next(err);
  }
}
async function createToken(req, res, next) {

  try {
    res.json(await login.createToken(req.body));
  } catch (err) {
    console.error(`Error while creating jwt`, err.message);
    next(err);
  }
}

// async function update(req, res, next) {
//   try {
//     res.json(await user.update(req.params.id, req.body));
//   } catch (err) {
//     console.error(`Error while updating user`, err.message);
//     next(err);
//   }
// }

// async function remove(req, res, next) {
//   try {
//     res.json(await user.remove(req.params.id));
//   } catch (err) {
//     console.error(`Error while deleting user`, err.message);
//     next(err);
//   }
// }

module.exports = {
  checkToken,
  createToken,
  checkTokenEXP
  // update,
  // remove
};
