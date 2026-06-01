resource "local_file" "student" {
  filename = "student.txt"
  content  = var.student_name
}