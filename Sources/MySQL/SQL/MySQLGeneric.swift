/// See `SQLQuery`.
public typealias MySQLBinaryOperator = GenericSQLBinaryOperator

/// See `SQLQuery`.
public typealias MySQLColumnConstraintAlgorithm = GenericSQLColumnConstraintAlgorithm<
    MySQLExpression, MySQLCollation, MySQLPrimaryKeyDefault, MySQLForeignKey
>

/// See `SQLQuery`.
public typealias MySQLColumnConstraint = GenericSQLColumnConstraint<
    MySQLIdentifier, MySQLColumnConstraintAlgorithm
>

/// See `SQLQuery`.
public typealias MySQLColumnDefinition = GenericSQLColumnDefinition<
    MySQLColumnIdentifier, MySQLDataType, MySQLColumnConstraint
>

/// See `SQLQuery`.
public typealias MySQLColumnIdentifier = GenericSQLColumnIdentifier<
    MySQLTableIdentifier, MySQLIdentifier
>

/// See `SQLQuery`.
public typealias MySQLForeignKeyAction = GenericSQLForeignKeyAction

/// See `SQLQuery`
public typealias MySQLCreateIndex = GenericSQLCreateIndex<
    MySQLIndexModifier, MySQLIdentifier, MySQLColumnIdentifier
>

/// See `SQLQuery`
public typealias MySQLCreateTable = GenericSQLCreateTable<
    MySQLTableIdentifier, MySQLColumnDefinition, MySQLTableConstraint
>

/// See `SQLQuery`.
public typealias MySQLDelete = GenericSQLDelete<
    MySQLTableIdentifier, MySQLExpression
>

/// See `SQLQuery`.
public typealias MySQLDirection = GenericSQLDirection

/// See `SQLQuery`.
public typealias MySQLDistinct = GenericSQLDistinct

/// See `SQLQuery`.
public typealias MySQLDropTable = GenericSQLDropTable<MySQLTableIdentifier>

/// See `SQLQuery`.
public typealias MySQLExpression = GenericSQLExpression<
    MySQLLiteral, MySQLBind, MySQLColumnIdentifier, MySQLBinaryOperator, MySQLFunction, MySQLQuery
>

/// See `SQLQuery`.
public typealias MySQLForeignKey = GenericSQLForeignKey<
    MySQLTableIdentifier, MySQLIdentifier, MySQLForeignKeyAction
>

/// See `SQLQuery`.
public typealias MySQLGroupBy = GenericSQLGroupBy<MySQLExpression>

/// See `SQLQuery`
public typealias MySQLIndexModifier = GenericSQLIndexModifier

/// See `SQLQuery`.
public typealias MySQLJoin = GenericSQLJoin<
    MySQLJoinMethod, MySQLTableIdentifier, MySQLExpression
>

/// See `SQLQuery`.
public typealias MySQLJoinMethod = GenericSQLJoinMethod

/// See `SQLQuery`.
public typealias MySQLLiteral = GenericSQLLiteral<MySQLDefaultLiteral, MySQLBoolLiteral>

/// See `SQLQuery`.
public typealias MySQLOrderBy = GenericSQLOrderBy<MySQLExpression, MySQLDirection>

/// See `SQLQuery`.
public typealias MySQLSelect = GenericSQLSelect<
    MySQLDistinct, MySQLSelectExpression, MySQLTableIdentifier, MySQLJoin, MySQLExpression, MySQLGroupBy, MySQLOrderBy
>

/// See `SQLQuery`.
public typealias MySQLSelectExpression = GenericSQLSelectExpression<MySQLExpression, MySQLIdentifier, MySQLTableIdentifier>

/// See `SQLQuery`.
public typealias MySQLTableConstraintAlgorithm = GenericSQLTableConstraintAlgorithm<
    MySQLIdentifier, MySQLExpression, MySQLCollation, MySQLForeignKey
>

/// See `SQLQuery`.
public typealias MySQLTableConstraint = GenericSQLTableConstraint<
    MySQLIdentifier, MySQLTableConstraintAlgorithm
>

/// See `SQLQuery`.
public typealias MySQLTableIdentifier = GenericSQLTableIdentifier<MySQLIdentifier>

/// See `SQLQuery`.
public typealias MySQLUpdate = GenericSQLUpdate<
    MySQLTableIdentifier, MySQLIdentifier, MySQLExpression
>
