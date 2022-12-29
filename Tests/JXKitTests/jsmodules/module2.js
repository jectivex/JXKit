const m1 = require('./module1')

exports.getName2 = function() {
    return m1.getName() + '2';
}
