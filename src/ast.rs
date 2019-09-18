pub struct Module {

}

pub struct ModuleHeader {

}

pub struct Identifier(pub String);

pub struct Ports {

}

pub struct Port {

}

pub enum PortDirection {
    Input,
    Output
}

pub struct ModuleItem {

}

pub struct NonPortModuleItem {

}

pub struct ModuleOrGenerateItem {

}

pub struct ModuleCommonItem {

}

pub struct AlwaysConstruct {
    pub keyword: AlwaysKeyword,
    pub statement: Statement
}

pub enum AlwaysKeyword {
    AlwaysComb
}

pub struct Statement {

}

pub struct Expression {

}

pub struct ConditionalStatement {

}

pub struct CondPredicate {

}

pub struct StatementItem {

}

pub struct BinaryOperator {

}

pub struct SeqBlock {

}