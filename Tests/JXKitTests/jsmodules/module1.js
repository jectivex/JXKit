var name = 'foo';

function getNameFunction() {
    return name;
}

class NameTypeClass {
    getClassName() {
        return 'class' + privateName();
    }
}

function privateName() {
    return 'private' + name;
}

exports.getName = getNameFunction;
exports.NameType = NameTypeClass;
