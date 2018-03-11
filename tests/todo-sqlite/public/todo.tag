<todo>
  <h2>{ opts.title }</h2>
  <todo-form></todo-form>
  <div each={ todo in todolist.todos } >
    <div><list todo={todo}></list></div>
  </div>
  <script>
    var self = this;
    todolist.on('refresh', function(){
      self.update()
    });
  </script>
</todo>