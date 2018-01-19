<list>
  {opts.todo.todo}&nbsp;<i onclick={delete} class="fa fa-times"></i>

  <script>
  delete() {
    var delid = opts.todo.todo_id;
    var deltodo = opts.todo.todo;

    fetch('http://localhost:8080/api/todo/delete', {
      method: 'POST',
      body: JSON.stringify({"todo_id": delid}),
      headers: new Headers({ "Content-type": "application/json; charset=UTF-8" })
    }).then(response => {
      return response.json();
    })
    .then
    (jsondata => {
      var newdata = jsondata;
      todolist.todos = newdata;
      todolist.trigger('refresh');
    });
  };
  </script>
</list>