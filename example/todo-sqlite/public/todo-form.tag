<todo-form>
  <input type="text" ref="addTodo" /> <i onclick={add} class="fa fa-plus"></i>

  <script>
  add ()
  {
    if (this.refs.addTodo.value) {
      fetch("http://localhost:8080/api/todo/add", {
        method: 'POST',
        body: JSON.stringify({"todo": this.refs.addTodo.value}),
        headers : new Headers({ "Content-type" : "application/json; charset=UTF-8" })
      }).then(response => {
        return response.json();
      })
      .then
      (jsondata => {
        var newdata = jsondata;
        todolist.todos = newdata;
        todolist.trigger('refresh');
      });
      this.refs.addTodo.value = null;
    }
    else {
      alert("入力してください！");
    }
  };
  </script>
</todo-form>