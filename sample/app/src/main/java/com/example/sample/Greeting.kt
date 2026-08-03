package com.example.sample

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp

@Composable
fun Greeting(name: String) {
    Surface {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(text = "Hello, $name", style = MaterialTheme.typography.headlineMedium)
            Button(onClick = {}) {
                Text("Tap me")
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
fun GreetingPreview() {
    Greeting("Neovim")
}

@Preview(name = "Wide", showBackground = true, widthDp = 480)
@Preview(name = "Narrow", showBackground = true, widthDp = 160)
@Composable
fun GreetingSizePreview() {
    Greeting("Compose")
}
