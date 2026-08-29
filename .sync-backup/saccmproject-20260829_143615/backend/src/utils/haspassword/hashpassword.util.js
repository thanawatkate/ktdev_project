const bcrypt = require('bcrypt');
const saltRounds = Number(process.env.SALTROUNDS);
require("dotenv").config()


async function hashPassword(myPlaintextPassword) {
    // console.log('myPlaintextPassword: ', myPlaintextPassword)
    let newPassword = ""
    if (myPlaintextPassword) {
        newPassword = await bcrypt
            .genSalt(saltRounds)
            .then(salt => {
                //    console.log('Salt: ', salt)
                return bcrypt.hash(myPlaintextPassword, salt)
            })
            .then(hash => {
                //    console.log('Hash: ', hash)
                return hash
            })
            .catch(err => console.error(err.message))
    }
    //console.log("hashPassword", newPassword)
    return newPassword

}

async function validatePassword(password, hash) {

    return await bcrypt
        .compare(password, hash)
        .then(res => {
            return res   // return true
        })
        .catch(err => console.error(err.message))
}


module.exports = {
    hashPassword,
    validatePassword
}
