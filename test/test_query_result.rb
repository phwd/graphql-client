require "graphql"
require "graphql/client/query_result"
require "minitest/autorun"

class TestQueryResult < MiniTest::Test
  def test_define_simple_query_result
    fragment = GraphQL.parse(<<-'GRAPHQL').definitions.first
      fragment PersonFragment on Person {
        name
        company
      }
    GRAPHQL
    person_klass = GraphQL::Client::QueryResult.wrap(fragment)

    person = person_klass.new("name" => "Josh", "company" => "GitHub")
    assert_equal "Josh", person.name
    assert_equal "GitHub", person.company
  end

  def test_snakecase_field_aliases
    fragment = GraphQL.parse(<<-'GRAPHQL').definitions.first
      fragment PersonFragment on Person {
        firstName
        lastName
      }
    GRAPHQL
    person_klass = GraphQL::Client::QueryResult.wrap(fragment)

    person = person_klass.new("firstName" => "Joshua", "lastName" => "Peek")
    assert_equal "Joshua", person.first_name
    assert_equal "Peek", person.last_name
  end

  def test_predicate_aliases
    fragment = GraphQL.parse(<<-'GRAPHQL').definitions.first
      fragment PersonFragment on Person {
        name
        company
      }
    GRAPHQL
    person_klass = GraphQL::Client::QueryResult.wrap(fragment)

    person = person_klass.new("name" => "Josh", "company" => nil)
    assert_equal true, person.name?
    assert_equal false, person.company?
  end

  def test_no_method_error
    fragment = GraphQL.parse(<<-'GRAPHQL').definitions.first
      fragment PersonFragment on Person {
        fullName
      }
    GRAPHQL
    person_klass = GraphQL::Client::QueryResult.wrap(fragment)
    person = person_klass.new("fullName" => "Joshua Peek")

    begin
      person.name
      flunk
    rescue NoMethodError => e
      assert_equal "undefined method `name' for #<GraphQL::Client::QueryResult fullName=\"Joshua Peek\">", e.to_s
    end
  end

  Person = GraphQL::Client::QueryResult.wrap(GraphQL.parse(<<-'GRAPHQL').definitions.first)
    fragment PersonFragment on Person {
      fullName
    }
  GRAPHQL

  def test_no_method_error_constant
    person = Person.new("fullName" => "Joshua Peek")

    begin
      person.name
      flunk
    rescue NoMethodError => e
      assert_equal "undefined method `name' for #<TestQueryResult::Person fullName=\"Joshua Peek\">", e.to_s
    end
  end

  def test_merge_classes
    fragments = GraphQL.parse(<<-'GRAPHQL').definitions
      fragment foo on Person {
        name
        company
      }

      fragment bar on Person {
        name
        login
      }
    GRAPHQL

    person1_klass = GraphQL::Client::QueryResult.wrap(fragments[0])
    person2_klass = GraphQL::Client::QueryResult.wrap(fragments[1])
    person3_klass = person1_klass | person2_klass
    assert_equal [:name, :company, :login], person3_klass.fields.keys
  end

  def test_merge_nested_classes
    fragments = GraphQL.parse(<<-'GRAPHQL').definitions
      fragment query1 on Query {
        viewer {
          name
          company
        }
      }

      fragment query2 on Query {
        viewer {
          name
          login
        }
      }
    GRAPHQL

    root1_klass = GraphQL::Client::QueryResult.wrap(fragments[0])
    root2_klass = GraphQL::Client::QueryResult.wrap(fragments[1])
    root3_klass = root1_klass | root2_klass

    assert_equal [:name, :company, :login], root3_klass.fields[:viewer].fields.keys
  end

  def test_query_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query FooQuery {
        version
      }
    GRAPHQL

    assert query = document.definitions.first
    assert query_klass = GraphQL::Client::QueryResult.wrap(query)
    assert_equal query, query_klass.source_node

    assert data = query_klass.new("version" => 42)
    assert_equal 42, data.version
  end

  def test_empty_query_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query FooQuery {
      }
    GRAPHQL

    assert query = document.definitions.first
    assert query_klass = GraphQL::Client::QueryResult.wrap(query)
    assert_equal query, query_klass.source_node

    assert query_klass.new({})
  end

  def test_field_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query {
        users {
          id
          name
        }
      }
    GRAPHQL

    assert query = document.definitions.first
    assert users_field = query.selections.first
    assert user_klass = GraphQL::Client::QueryResult.wrap(users_field)
    assert_equal users_field, user_klass.source_node

    assert user = user_klass.new("id" => 1, "name" => "Josh")
    assert_equal 1, user.id
    assert_equal "Josh", user.name
  end

  def test_aliased_field_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query {
        users {
          relayID: id
          fullName: name
        }
      }
    GRAPHQL

    assert query = document.definitions.first
    assert users_field = query.selections.first
    assert user_klass = GraphQL::Client::QueryResult.wrap(users_field)
    assert_equal users_field, user_klass.source_node

    assert user = user_klass.new("relayID" => 1, "fullName" => "Joshua Peek")
    assert_equal 1, user.relay_id
    assert_equal "Joshua Peek", user.full_name
  end

  def test_merge_nested_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query {
        users {
          id
          name

          issues {
            count
            assignedCount
          }

          issues {
            count
            authoredCount
          }
        }
      }
    GRAPHQL

    assert query = document.definitions.first
    assert users_field = query.selections.first
    assert user_klass = GraphQL::Client::QueryResult.wrap(users_field)
    assert_equal users_field, user_klass.source_node

    assert user = user_klass.new(
      "id" => 1,
      "name" => "Josh",
      "issues" => {
        "count" => 3,
        "assignedCount" => 2,
        "authoredCount" => 1
      }
    )
    assert_equal 1, user.id
    assert_equal "Josh", user.name
    assert_equal 3, user.issues.count
    assert_equal 2, user.issues.assigned_count
    assert_equal 1, user.issues.authored_count
  end

  def test_merge_nested_inline_fragment_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query {
        users {
          id
          name

          ... on User {
            issues {
              count
              assignedCount
            }
          }

          ... on User {
            issues {
              count
              authoredCount
            }
          }
        }
      }
    GRAPHQL

    assert query = document.definitions.first
    assert users_field = query.selections.first
    assert user_klass = GraphQL::Client::QueryResult.wrap(users_field)
    assert_equal users_field, user_klass.source_node

    assert user = user_klass.new(
      "id" => 1,
      "name" => "Josh",
      "issues" => {
        "count" => 3,
        "assignedCount" => 2,
        "authoredCount" => 1
      }
    )
    assert_equal 1, user.id
    assert_equal "Josh", user.name
    assert_equal 3, user.issues.count
    assert_equal 2, user.issues.assigned_count
    assert_equal 1, user.issues.authored_count
  end

  def test_fragment_definition_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      fragment Viewer on User {
        id
        name
      }
    GRAPHQL

    assert viewer_fragment = document.definitions.first
    assert viewer_klass = GraphQL::Client::QueryResult.wrap(viewer_fragment)
    assert_equal viewer_fragment, viewer_klass.source_node

    assert viewer = viewer_klass.new("id" => 1, "name" => "Josh")
    assert_equal 1, viewer.id
    assert_equal "Josh", viewer.name
  end

  def test_empty_fragment_definition_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      fragment Viewer on User {
      }
    GRAPHQL

    assert viewer_fragment = document.definitions.first
    assert viewer_klass = GraphQL::Client::QueryResult.wrap(viewer_fragment)
    assert_equal viewer_fragment, viewer_klass.source_node

    assert viewer_klass.new({})
  end

  def test_inline_fragment_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query {
        user {
          ... on User {
            id
            name
          }
        }
      }
    GRAPHQL

    assert query = document.definitions.first
    assert user_field = query.selections.first
    assert user_fragment = user_field.selections.first

    assert user_klass = GraphQL::Client::QueryResult.wrap(user_field)
    assert_equal user_field, user_klass.source_node
    assert user = user_klass.new("id" => 1, "name" => "Josh")
    assert_equal 1, user.id
    assert_equal "Josh", user.name

    assert user_klass = GraphQL::Client::QueryResult.wrap(user_fragment)
    assert_equal user_fragment, user_klass.source_node
    assert user = user_klass.new("id" => 1, "name" => "Josh")
    assert_equal 1, user.id
    assert_equal "Josh", user.name
  end

  def test_shadowed_fragment_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query {
        user {
          ...UserFragment
        }
      }

      fragment UserFragment on User {
        id
        name
      }
    GRAPHQL

    assert query = document.definitions.first
    assert user_field = query.selections.first
    assert user_klass = GraphQL::Client::QueryResult.wrap(user_field)
    assert_equal user_field, user_klass.source_node

    assert user = user_klass.new("id" => 1, "name" => "Josh")
    refute user.respond_to?(:id)
    refute user.respond_to?(:name)
  end

  def test_shadowed_inline_fragment_with_overlapping_fields_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query {
        user {
          id
          login
          ...UserFragment
        }
      }

      fragment UserFragment on User {
        id
        name
      }
    GRAPHQL

    assert query = document.definitions.first
    assert user_field = query.selections.first
    assert user_klass = GraphQL::Client::QueryResult.wrap(user_field)
    assert_equal user_field, user_klass.source_node

    assert user = user_klass.new("id" => 1, "login" => "josh", "name" => "Josh")
    assert_equal 1, user.id
    assert_equal "josh", user.login
    refute user.respond_to?(:name)
  end

  def test_empty_inline_fragment_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query {
        user {
          ... on User {
          }
        }
      }
    GRAPHQL

    assert query = document.definitions.first
    assert user_field = query.selections.first
    assert user_fragment = user_field.selections.first
    assert user_klass = GraphQL::Client::QueryResult.wrap(user_fragment)
    assert_equal user_fragment, user_klass.source_node

    assert user_klass.new({})
  end

  def test_spread_fragment_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query {
        user {
          ...Viewer
        }
      }

      fragment Viewer on User {
        id
        name
      }
    GRAPHQL

    assert query = document.definitions.first
    assert fragment = document.definitions.last

    assert result = GraphQL::Client::QueryResult.wrap(query).new("user" => { "id" => 1, "name" => "Josh" })
    refute result.user.respond_to?(:id)
    refute result.user.respond_to?(:name)

    assert user = GraphQL::Client::QueryResult.wrap(fragment).new("id" => 1, "name" => "Josh")
    assert_equal 1, user.id
    assert_equal "Josh", user.name
  end

  def test_shadowed_spread_fragment_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query {
        user {
          ...Viewer
        }
      }

      fragment Viewer on User {
        id
        name
      }
    GRAPHQL

    assert query = document.definitions.first
    assert user_field = query.selections.first

    assert user_klass = GraphQL::Client::QueryResult.wrap(user_field)
    assert_equal user_field, user_klass.source_node
    assert user = user_klass.new("id" => 1, "name" => "Josh")
    refute user.respond_to?(:id)
    refute user.respond_to?(:name)

    assert user_klass = GraphQL::Client::QueryResult.wrap(user_field)
    assert_equal user_field, user_klass.source_node
    assert user = user_klass.new("id" => 1, "name" => "Josh")
    refute user.respond_to?(:id)
    refute user.respond_to?(:name)
  end

  def test_shadowed_spread_fragment_overlapping_fields_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query {
        user {
          id
          ...Viewer
          login
        }
      }

      fragment Viewer on User {
        id
        name
      }
    GRAPHQL

    assert query = document.definitions.first
    assert user_field = query.selections.first

    assert user_klass = GraphQL::Client::QueryResult.wrap(user_field)
    assert_equal user_field, user_klass.source_node
    assert user = user_klass.new("id" => 1, "login" => "josh", "name" => "Josh")
    assert_equal 1, user.id
    assert_equal "josh", user.login
    refute user.respond_to?(:name)

    assert user_klass = GraphQL::Client::QueryResult.wrap(user_field)
    assert_equal user_field, user_klass.source_node
    assert user = user_klass.new("id" => 1, "login" => "josh", "name" => "Josh")
    assert_equal 1, user.id
    assert_equal "josh", user.login
    refute user.respond_to?(:name)
  end

  def test_relay_connection_enumerator
    query = GraphQL.parse(<<-'GRAPHQL').definitions.first
      query MoreRebelShipsQuery {
        rebels {
          name,
          ships(first: 2) {
            edges {
              cursor
              node {
                name
              }
            }
          }
        }
      }
    GRAPHQL

    assert query_klass = GraphQL::Client::QueryResult.wrap(query)
    data = query_klass.new("rebels" => {
                             "name" => "Alliance to Restore the Republic",
                             "ships" => {
                               "edges" => [
                                 {
                                   "cursor" => "YXJyYXljb25uZWN0aW9uOjA=",
                                   "node" => {
                                     "name" => "X-Wing"
                                   }
                                 },
                                 {
                                   "cursor" => "YXJyYXljb25uZWN0aW9uOjE=",
                                   "node" => {
                                     "name" => "Y-Wing"
                                   }
                                 }
                               ]
                             }
                           })

    assert_equal "Alliance to Restore the Republic", data.rebels.name
    assert_equal 2, data.rebels.ships.edges.length
    assert_equal "X-Wing", data.rebels.ships.edges[0].node.name
    assert_equal "Y-Wing", data.rebels.ships.edges[1].node.name

    assert_equal ["X-Wing", "Y-Wing"], data.rebels.ships.each_node.map(&:name)
  end
end
